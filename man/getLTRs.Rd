% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/annotations.R
\name{getLTRs}
\alias{getLTRs}
\title{Getter of LTR class TEs from parsed RepeatMasker annotations}
\usage{
getLTRs(
  parsed_ann,
  relLength = 0.9,
  full_length = TRUE,
  partial = FALSE,
  soloLTR = FALSE,
  otherLTR = FALSE
)
}
\arguments{
\item{parsed_ann}{A \link[GenomicRanges:GRangesList-class]{GRangesList} 
object obtained from parsing RepeatMasker annotations
with \code{OneCodeToFindThemAll()} or 
\code{rmskatenaparser()} function.}

\item{relLength}{(Default 0.9) Numeric value that can take values between 0
to 1. Sets the minimum relative length required for
features. Elements with a lower relative length than
\code{relLength} will be filtered. The relative length
used is the one obtained by \code{OneCodeToFindThemAll()}
or \code{rmskatenaparser()}.
(length of the reconstructed TE / length of the reference).}

\item{full_length}{(Default TRUE) A logical. Should reconstructed 
full-length LTR TEs (elements with structure 
LTR - internal region - LTR) be reported?}

\item{partial}{(Default FALSE) A logical. Should partially reconstructed
LTR TEs be reported (structure LTR - internal region or 
internal region - LTR)?}

\item{soloLTR}{(Default FALSE) A logical. Should solo LTRs be reported?
Note that only fragments unambiguously identified as LTRs
thanks to the identification of their equivalent internal
region are considered as LTRs.}

\item{otherLTR}{(Default FALSE) A logical. Should other TEs from the LTR
class, not included in any of the previous three categories,  
be reported? These include TEs from LTR class that cannot be
unambiguously identified as LTR o internal region, and thus
cannot be reconstructed into partial or full-length 
elements; as well as solo internal regions.}
}
\value{
A \link[GenomicRanges:GRangesList-class]{GRangesList} object with
        annotations from LTR.
}
\description{
Getter of LTR class TEs from parsed RepeatMasker annotations
}
\details{
Retrieves LTR class TEs from RepeatMasker annotations after parsing using
the \code{OneCodeToFindThemAll()} or \code{rmskatenaparser()} function. 
The \code{relLength} parameter
can be used to filter out elements with a lower relative length. The other
parameters can be used to fine-tune the type of elements to be reported.
}
\examples{
rmsk_gr <- annotaTEs(genome = "dm6", parsefun = rmskatenaparser,
                     strict = FALSE)
rmsk_gr_ltr <- getLTRs(rmsk_gr, relLength = 0.95, full_length = TRUE,
                       partial = TRUE)
 
}
