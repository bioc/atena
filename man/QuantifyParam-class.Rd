% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/AllClasses.R
\docType{class}
\name{QuantifyParam-class}
\alias{QuantifyParam-class}
\alias{path,QuantifyParam-method}
\alias{features,QuantifyParam-method}
\alias{features}
\title{Atena parameter class}
\usage{
\S4method{path}{QuantifyParam}(object)

\S4method{features}{QuantifyParam}(object)
}
\arguments{
\item{object}{A \linkS4class{QuantifyParam} object.}
}
\value{
\code{path()}: Filesystem paths to the BAM files in the input
parameter object.

\code{features()}: The \code{GenomicRanges} or
\code{GenomicRangesList} object with the features in the input parameter
object.
}
\description{
This is a virtual class from which other classes are derived
for storing parameters provided to quantification methods of
transposable elements from RNA-seq data.
}
\section{Slots}{

\describe{
\item{\code{bfl}}{A \linkS4class{BamFileList} object.}

\item{\code{features}}{A \linkS4class{GRanges} object.}

\item{\code{aggregateby}}{Character vector with column names in the annotation
to be used to aggregate quantifications.}

\item{\code{ovMode}}{Character vector indicating the overlapping mode. Available
options are: "ovUnion" (default) and "ovIntersectionStrict",
which implement the corresponding methods from HTSeq
(\url{https://htseq.readthedocs.io/en/release_0.11.1/count.html}).
In the TEtranscripts, ERVmap and Telescope methods ambiguous
alignments (alignments overlapping > 1 feature) are addressed
differently depending on the method. In the atena method, those
overlaps are not counted.}
}}

\examples{
bamfiles <- list.files(system.file("extdata", package="atena"),
                       pattern="*.bam", full.names=TRUE)
rmskat <- annotaTEs(genome = "dm6", parsefun = rmskatenaparser, 
                    strict = FALSE, insert = 500)
rmskLTR <- getLTRs(rmskat, relLength = 0.8, 
                   full_length = TRUE, 
                   partial = TRUE)
ttpar <- TEtranscriptsParam(bamfiles, 
                            teFeatures = rmskLTR,
                            singleEnd = TRUE, 
                            ignoreStrand=TRUE)
path(ttpar)

}
\seealso{
\code{\link{ERVmapParam-class}}
\code{\link{TelescopeParam-class}}
\code{\link{TEtranscriptsParam-class}}
\code{\link{atenaParam-class}}
}
