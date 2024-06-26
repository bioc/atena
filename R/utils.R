## pretty-print names (private)
.pprintnames <- function(x) {
    y <- x
    if (length(x) > 2)
        y <- c(y[1], "...", y[length(y)])
    y <- paste(y, collapse=", ")
    y
}

## private function .checkPhenoData()

#' @importFrom S4Vectors nrow rownames
.checkPhenodata <- function(pdata, nr) {
    if (!is.null(pdata)) {
        if (nrow(pdata) != nr)
            stop("number of rows in 'phenodata' is different than the number of input BAM files in the input parameter object 'x'.")
        if (is.null(rownames(pdata)))
            stop("'phenodata' has no row names.")
    }
}

## private function .createColumnData()

#' @importFrom S4Vectors DataFrame
.createColumnData <- function(m, pdata) {
    colData <- DataFrame(row.names=gsub(".bam$", "", colnames(m)))
    if (!is.null(pdata))
        colData <- pdata
    
    colData
}

## private function .checkBamFileListArgs()
## adapted from GenomicAlignments/R/summarizeOverlaps-methods.R

#' @importFrom Rsamtools BamFileList asMates asMates<-
.checkBamFileListArgs <- function(bfl, singleEnd, fragments) {
    if (missing(bfl) || !class(bfl) %in% c("character", "BamFileList"))
        stop("argument 'bfl' should be either a string character vector of BAM file names or a 'BamFileList' object")
    
    if (length(bfl) == 0)
        stop("argument 'bfl' is empty")
  
    if (is.character(bfl)) {
        mask <- vapply(bfl, FUN=file.exists, FUN.VALUE=logical(1))
        if (any(!mask))
            stop(sprintf("The following input BAM files cannot be found:\n%s",
                         paste(paste("  ", bfl[!mask]), collapse="\n")))
    }
    
    if (!is(bfl, "BamFileList"))
        bfl <- BamFileList(bfl, asMates=!singleEnd)
    
    if (singleEnd) {
        if (all(isTRUE(asMates(bfl))))
            stop("cannot specify both 'singleEnd=TRUE' and 'asMates=TRUE'")
        # if (fragments)
        #     stop("when 'fragments=TRUE', 'singleEnd' should be FALSE")
    } else
        asMates(bfl) <- TRUE
    
    bfl
}

## private function .checkBamReadMapper()
## extracts the name of the read mapper software from one or more BAM files
## parameters: bamfiles - BAM file names

#' @importFrom Rsamtools scanBamHeader
.checkBamReadMapper <- function(bamfiles) {
    if (missing(bamfiles) || !"character" %in% class(bamfiles))
        stop("argument 'bamfiles' should be a string character vector of BAM file names")
    
    mask <- vapply(bamfiles, FUN = file.exists, FUN.VALUE = logical(1L))
    if (any(!mask))
        stop(sprintf("The following input BAM files cannot be found:\n%s",
                    paste(paste("  ", bamfiles[!mask]), collapse="\n")))
    
    hdr <- scanBamHeader(bamfiles)
    readaligner <- vapply(hdr, FUN = function(x) {
                            ra <- NA_character_
                            if (!is.null(x$text[["@PG"]])) {
                                pgstr <- x$text[["@PG"]]
                                mt <- gregexpr("^PN:", pgstr)
                                wh <- which(vapply(mt, FUN = function(x) x!=-1,
                                            FUN.VALUE = logical(1L)))
                                ra <- substr(pgstr[[wh]],
                                            attr(mt[[wh]], "match.length") + 1,
                                            100000L)
                            }
                            tolower(ra)
                    }, FUN.VALUE = character(1))
    readaligner <- readaligner[!duplicated(readaligner)]
    readaligner <- as.vector(readaligner[!is.na(readaligner)])
    if (length(readaligner) == 0)
        warning("no read aligner software information in BAM files.")
    if (any(readaligner[1] != readaligner))
        warning(sprintf("different read aligner information in BAM files. Assuming %s",
                        readaligner[1]))
    
    readaligner[1]
}

## private function .processFeatures()
## builds a single 'GRanges' or 'GRangesList' object from input TE and gene
## features.
## parameters: teFeatures - a 'GRanges' or 'GRangesList' object with
##                          TE annotations
##             teFeaturesobjname - the name of 'teFeatures'
##             geneFeatures - a 'GRanges' or 'GRangesList' object with
##                            gene annotations
##             geneFeaturesobjname - the name of 'geneFeatures'
##             aggregateby - names of metadata columns in 'teFeatures'
##                           to be used later for aggregating estimated
##                           counts.

#' @importFrom S4Vectors mcols Rle decode DataFrame
#' @importFrom GenomeInfoDb seqlevels<- seqlevels
#' @importFrom GenomicRanges mcols<- mcols
.processFeatures <- function(teFeatures, teFeaturesobjname, geneFeatures,
                             geneFeaturesobjname, aggregateby,
                             aggregateexons) {
    
    if (missing(teFeatures))
        stop("missing 'teFeatures' argument.")
    
    if (!is(teFeatures, "GRanges") && !is(teFeatures, "GRangesList"))
        stop(sprintf("TE features object '%s' should be either a 'GRanges' or a 'GRangesList' object.",
                     teFeaturesobjname))
    
    if (is.null(names(teFeatures)) && length(aggregateby) == 0)
        stop(sprintf("the TE features object '%s' has no names and no aggregation metadata columns have been specified.",
                     teFeaturesobjname))
    
    mdteFeatures <- mcols(teFeatures)
    features <- NULL
    if (is(teFeatures, "GRangesList"))
        teFeatures <- unlist(teFeatures)
    
    if (length(aggregateby) > 0) {
        mask <- !aggregateby %in% colnames(mcols(teFeatures))
        if (any(mask)) {
            fstr <- sprintf(paste("%%s not in metadata columns of the TE",
                                  "features object %s."), teFeaturesobjname)
            stop(sprintf(fstr, paste(aggregateby[mask], collapse=", ")))
        }
        mask <- aggregateby %in% c("Status", "RelLength", "Class")
        if (any(mask))
            stop(sprintf("%s cannot be used to aggregate quantifications.",
                         paste(aggregateby[mask], collapse=", ")))

    }
    
    if (!is.null(geneFeatures)) {
        if (is(geneFeatures, "GRangesList"))
            geneFeatures <- unlist(geneFeatures)

        if (!"type" %in% colnames(mcols(geneFeatures)))
          mcols(geneFeatures)$type <- "exon"
        
        features <- .joinTEsGenes(teFeatures, geneFeatures, geneFeaturesobjname)
    } else {
        features <- teFeatures
        mcols(features)$isTE <- rep(TRUE, length(features))
    }
    
    iste <- decode(mcols(features)$isTE)
    
    if (!is.null(geneFeatures)) {
        if (!all(iste) && !is.null(mcols(geneFeatures)$type)) {
            if (is(features, "GRanges")) {
                iste <- aggregate(iste, by=list(names(features)), unique)
                features <- .groupGeneExons(features, aggregateexons)
                mtname <- match(names(features), iste$Group.1)
                iste <- iste[mtname,"x"]
                
            } else if (is(geneFeatures, "GRanges")) {
                ## when gene annotations were a GRanges but TE annotations
                ## a GRangesList, aggregate genes at the exon level only
                features_g <- unlist(features[which(!iste)])
                mcols(features_g)$isTE <- FALSE
                mcols(features_g)$type <- mcols(features)[which(!iste), "type"]
                features_g <- .groupGeneExons(features_g,
                                              aggregateexons)
                mcols(features_g)$isTE <- FALSE
                mcols(features_g)$type <- "exon"
                iste_g <- unlist(lapply(relist(iste[which(!iste)], features_g),
                                        function(x) x[1]),  use.names=FALSE)
                iste <- c(iste[which(iste)], iste_g)
                features <- c(features[which(iste)], features_g)
            }
        }
      
    } else if (aggregateexons && is(features, "GRanges") &&
               !is.null(names(features))) {
        iste <- aggregate(iste, by=list(names(features)), unique)
        features <- .groupGeneExons(features, aggregateexons)
        mtname <- match(names(features), iste$Group.1)
        iste <- iste[mtname, "x"]
    }
    if (!is.null(names(features))) {
      mdat <- DataFrame(ids=names(features), isTE=iste)
      mdteFeatures$ids <- rownames(mdteFeatures)
      mdat <- merge(mdteFeatures, mdat, all=TRUE)
      mt <- match(names(features), mdat$ids)
      stopifnot(all(!is.na(mt))) ## QC
      mcols(features) <- mdat[mt, -match("ids", colnames(mdat))]
    }

    features
}


## private function .groupGeneExons()
## groups exons from the same gene creating a 'GRangesList' object
.groupGeneExons <- function(features, aggregateexons) {
    if (aggregateexons) {
        if (!all(features$isTE) & !any(mcols(features)$type == "exon")) {
            stop(".groupGeneExons: no genes with value 'exon' in 'type' column of the metadata of the 'GRanges' or 'GRangesList' object with gene annotations.")
        }
        yesexon <- rep(TRUE, length(features))
        if (!is.null(mcols(features)$type)) {
            yesexon <- mcols(features)$type == "exon"
            yesexon[is.na(yesexon)] <- FALSE
        }
        features <- features[mcols(features)$isTE | yesexon]
        featuressplit <- split(x = features, f = names(features))
    } else {
        features_g <- features[!features$isTE]
        features_t <- features[features$isTE]
        features_t_grl <- split(x = features_t, f = seq_along(features_t))
        names(features_t_grl) <- names(features_t)
        if (!any(mcols(features_g)$type == "exon")) {
            stop(".groupGeneExons: no genes with value 'exon' in 'type' column of the metadata of the 'GRanges' or 'GRangesList' object with gene annotations.")
        }
        features_g <- features_g[mcols(features_g)$type == "exon"]
        featuressplit <- split(x = features_g, f = names(features_g))
        featuressplit <- c(features_t_grl, featuressplit)
    }
    featuressplit
}


## private function .consolidateFeatures()
## builds a 'GRanges' or 'GRangesList' object
## grouping TE features, if necessary, and
## adding gene features, if available.
## parameters: x - TEtranscriptsParam object
##             fnames - feature names vector to which
##                      consolidated features should match

#' @importFrom methods is
#' @importFrom S4Vectors split
#' @importFrom IRanges IRanges IRangesList CharacterList unique
#' @importFrom GenomicRanges GRangesList GRanges
.consolidateFeatures <- function(x, fnames, whnofeat=integer(0)) {
    
    if (length(whnofeat) > 0 && !is(x, "TelescopeParam") &&
        !is(x, "atenaParam"))
        stop(paste("internal error: call to .consolidateFeatures() with",
                   "a non-empty whnofeat and the wrong parameter class."))

    cfeatures <- features(x)
    if (length(x@aggregateby) > 0) {
        iste <- mcols(features(x))$isTE
        teFeatures <- features(x)
        if (!is.null(iste) && any(iste))
            teFeatures <- features(x)[iste]
    
        f <- .factoraggregateby(teFeatures, x@aggregateby)
        md <- mcols(teFeatures)
        if (all(c("Status", "RelLength", "Class") %in% colnames(md))) {
            astatus <- unique(CharacterList(split(md$Status, f)))
            if (max(lengths(astatus)) == 1)
              astatus <- unlist(astatus)
            arlen <- sapply(split(md$RelLength, f), mean)
            aclass <- unique(CharacterList(split(md$Class, f)))
            if (max(lengths(aclass)) == 1)
              aclass <- unlist(aclass)
            md <- DataFrame(Status=astatus, RelLength=arlen, Class=aclass)
        } else
            md <- DataFrame(matrix(character(0), nrow=length(unique(f))))
        
        md$isTE <- rep(TRUE, nrow(md))

        if (is(teFeatures, "GRangesList")) {
            f <- rep(f, times=lengths(teFeatures))
            teFeatures <- unlist(teFeatures)
        }
        cfeatures <- split(teFeatures, f)
        mcols(cfeatures) <- md
    
        if (!is.null(iste) && any(!iste)) {
            geneFeatures <- features(x)[!iste]
            cfeatures <- c(cfeatures, geneFeatures)
        }
        stopifnot(length(cfeatures) == length(fnames)) ## QC
    }
    
    stopifnot(length(cfeatures) == length(fnames)) ## QC
    mt <- match(fnames, names(cfeatures))
    stopifnot(all(!is.na(mt))) ## QC
    cfeatures <- cfeatures[mt]
    
    if (length(whnofeat) > 0) {
        nofeat_gr <- GRanges(seqnames="chrNofeature", 
                             ranges=IRanges(start=1, end=1),
                             isTE=FALSE)
        if (length(whnofeat) == 1) {
            names(nofeat_gr) <- "no_feature"
            
        } else {
            nofeat_gr <- rep(nofeat_gr, length(whnofeat))
            names(nofeat_gr) <- paste0("no_feature", seq_along(whnofeat))
        }
        
        seqlev <- unique(c(seqlevels(cfeatures), seqlevels(nofeat_gr)))
        seqlevels(cfeatures) <- seqlev
        seqlevels(nofeat_gr) <- seqlev
        lencfeatwonofeat <- length(cfeatures)
        cfeatures <- c(cfeatures, nofeat_gr)
        rng <- (lencfeatwonofeat+1):length(cfeatures)
        mcols(cfeatures)$isTE[rng] <- FALSE
    }
    cfeatures
}


## private function .factoraggregateby()
## builds a factor with as many values as the
## length of the input annotations in 'ann', where
## every value is made by pasting the columns in
## 'aggby' separated by ':'.
## parameters: ann - GRanges object with annotations
##             aggby - names of metadata columns in 'ann'
##                     to be pasted together

#' @importFrom GenomicRanges mcols
.factoraggregateby <- function(ann, aggby) {
    if (is(ann,"GRangesList")) {
        anngrl <- ann
        ann <- unlist(ann)
    }
    stopifnot(all(aggby %in% colnames(mcols(ann)))) ## QC
    if (length(aggby) == 1) {
        f <- mcols(ann)[, aggby]
    } else {
        spfstr <- paste(rep("%s", length(aggby)), collapse=":")
        f <- do.call("sprintf", c(spfstr, as.list(mcols(ann)[, aggby])))
    }
    
    if (exists("anngrl")) {
      # Using the aggby of the 1st GRanges in each element of the GRangesList
      f <- unlist(lapply(relist(f, anngrl), function(x) x[1]))
    }
    f
}

## private function .getReadFunction()
## borrowed from GenomicAlignments/R/summarizeOverlaps-methods.R
.getReadFunction <- function(singleEnd, fragments) {
    if (singleEnd) {
        FUN <- readGAlignments
    } else {
        if (fragments)
            FUN <- readGAlignmentsList
        else
            FUN <- readGAlignmentPairs
    }
    
    FUN
}

## private function .appendHits()
## appends the second Hits object to the end of the first one
## assuming they have identical right nodes

#' @importFrom S4Vectors nLnode nRnode isSorted from to Hits
.appendHits <- function(hits1, hits2) {
    stopifnot(nRnode(hits1) == nRnode(hits2))
    stopifnot(isSorted(from(hits1)) == isSorted(from(hits2)))
    hits <- c(Hits(from=from(hits1), to=to(hits1),
                    nLnode=nLnode(hits1)+nLnode(hits2),
                    nRnode=nRnode(hits1), sort.by.query=isSorted(from(hits1))),
            Hits(from=from(hits2)+nLnode(hits1), to=to(hits2),
                    nLnode=nLnode(hits1)+nLnode(hits2),
                    nRnode=nRnode(hits2), sort.by.query=isSorted(from(hits2))))
    hits
}


#' @importFrom GenomeInfoDb seqlevels<- seqlevels
#' @importFrom GenomeInfoDb seqlevelsStyle seqlevelsStyle<-
#' @importFrom GenomicRanges mcols<-
.joinTEsGenes <- function(teFeatures, geneFeatures, geneFeaturesobjname) {
    
    if (!is(geneFeatures, "GRanges") && !is(geneFeatures, "GRangesList"))
        stop(sprintf("gene features object '%s' should be either a 'GRanges' or a 'GRangesList' object.",
                    geneFeaturesobjname))
    
    if (is.null(names(geneFeatures)))
        stop(sprintf("gene features object '%s' has no 'names()'",
                     geneFeaturesobjname))
    
    if (any(names(geneFeatures) %in% names(teFeatures)))
        stop("gene features have some common identifiers with the TE features.")
    
    if (length(geneFeatures) == 0)
        stop(sprintf("gene features object '%s' is empty.", geneFeaturesobjname))
    
    seqlevelsStyle(geneFeatures) <- seqlevelsStyle(teFeatures)[1]
    slev <- unique(c(seqlevels(teFeatures), seqlevels(geneFeatures)))
    seqlevels(teFeatures) <- slev
    seqlevels(geneFeatures) <- slev
    features <- c(teFeatures, geneFeatures)
    temask <- Rle(rep(FALSE, length(teFeatures) + length(geneFeatures)))
    temask[seq_along(teFeatures)] <- TRUE
    mcols(features)$isTE <- temask
    features
}

#' @importFrom S4Vectors queryHits subjectHits
#' @importFrom Matrix Matrix
.buildOvValuesMatrix <- function(x, ov, values, aridx, ridx, fidx) {
    stopifnot(class(values) %in% c("logical", "integer", "numeric")) ## QC
    ovmat <- Matrix(do.call(class(values), list(1)),
                    nrow=length(ridx), ncol=length(fidx))
    mt1 <- match(aridx[queryHits(ov)], ridx)
    mt2 <- match(subjectHits(ov), fidx)
    
    if (is(x, "TelescopeParam") | is(x, "atenaParam")) {
        mtov <- cbind(mt1, mt2)
        mtalign <- match(paste(mtov[,1],mtov[,2],sep = ":"),
                         unique(paste(mtov[,1],mtov[,2], sep = ":")))
        s <- split(x = values[queryHits(ov)], f = mtalign)
        if (is(x, "TelescopeParam")) {
          saln <- unlist(lapply(s, max), use.names = FALSE)
        } else {
          saln <- unlist(lapply(s, sum), use.names = FALSE)
        }
        values <- saln[mtalign]
    } else {
        values <- values[queryHits(ov)]
    }
    
    ovmat[cbind(mt1, mt2)] <- values
    
    ovmat
}


.getMaskUniqueAln <- function(alnreadids) {
    maskuniqaln <- !(duplicated(alnreadids) |
                         duplicated(alnreadids, fromLast = TRUE))
    maskuniqaln
}


.checkOvandsaln <- function(ov, salnmask) {
    if (length(ov) == 0) {
        stop(".qtex: no overlaps were found between reads and features")
    }
    if (!any(salnmask)) {
        warning("secondary alignments are not present in the SAM/BAM file. The quantification of features will proceed without taking into account overlaps of secondary alignments.")
    }
}

## private function .matchSeqinfo()
#' @importFrom GenomeInfoDb seqlengths keepSeqlevels seqlevelsStyle
#' @importFrom GenomeInfoDb seqlevelsStyle<- seqinfo seqinfo<- seqlevels
#' @importFrom GenomeInfoDb genome genome<-
.matchSeqinfo <- function(gal, features, verbose=TRUE) {
  stopifnot("GAlignments" %in% class(gal) ||
            "GAlignmentPairs" %in% class(gal) ||
            "GAlignmentsList" %in% class(gal) ||
            "GRanges" %in% class(features) || 
            "GRangesList" %in% class(features)) ## QC
  
  if (length(intersect(seqlevelsStyle(gal), seqlevelsStyle(features))) > 0)
    return(gal)

  seqlevelsStyle(gal) <- seqlevelsStyle(features)[1]
  slengal <- seqlengths(gal)
  slenf <- seqlengths(features)
  commonchr <- intersect(names(slengal), names(slenf))
  slengal <- slengal[commonchr]
  slenf <- slenf[commonchr]
  if (any(slengal != slenf)) {
    if (sum(slengal != slenf) == 1 && verbose) {
      message(sprintf(paste("Chromosome %s has different lengths",
                            "between the input BAM and the annotations",
                            "This chromosome will",
                            "be discarded from further analysis",
                            sep=" "),
                      paste(commonchr[which(slengal != slenf)],
                            collapse=", ")))
      
    } else if (verbose) {
      message(sprintf(paste("Chromosomes %s have different lengths",
                            "between the input BAM and the annotations",
                            "These chromosomes",
                            "will be discarded from further analysis",
                            sep=" "),
                      paste(commonchr[which(slengal != slenf)],
                            collapse=", ")))
    }
    if (sum(slengal == slenf) == 0)
      stop(paste("None of the chromosomes in the input BAM file has the",
                 "same length as the chromosomes in the input annotations.",
                 sep = " "))
    gal <- keepSeqlevels(gal, commonchr[slengal == slenf],
                         pruning.mode="coarse")
    commonchr <- commonchr[slengal == slenf]
  }
  
  ## set the seqinfo information to the one of the annotations
  mt <- match(commonchr, seqlevels(gal))
  seqinfo(gal, new2old=mt, pruning.mode="coarse") <- seqinfo(features)[commonchr]
  
  gal
}
