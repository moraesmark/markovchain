setClass("ctmc",
         representation(states = "character",
                        byrow = "logical",
                        generator = "matrix",
                        name = "character"),
         prototype(states = c("a", "b"), byrow = TRUE,
                   generator = matrix(data = c(-1, 1, 1, -1), byrow = TRUE, nrow = 2,
                                      dimnames = list(c("a", "b"), c("a", "b"))),
                   name = "Unnamed CTMC")
)

setMethod("initialize",
          signature(.Object = "ctmc"),
          function (.Object, states, byrow, generator,name,...) {
            # put the standard markovchain 
            if(missing(generator)) generator=matrix(data=c(-1, 1, 1, -1), #create a naive matrix
                                                    nrow=2,
                                                    byrow=TRUE, 
                                                    dimnames=list(c("a", "b"), c("a", "b"))
            )
            
            # check names of transition matrix
            if(all(is.null(rownames(generator)), is.null(colnames(generator)))==TRUE) { #if all names are missing it initializes them to "1", "2",...
              if(missing(states)) {
                nr=nrow(generator)
                stateNames<-as.character(seq(1:nr))
              } else {stateNames=states}
              
              rownames(generator)=stateNames
              colnames(generator)=stateNames
            } else if(is.null(rownames(generator))) { #fix when rownames null
              rownames(generator)=colnames(generator)
            } else if(is.null(colnames(generator))) { #fix when colnames null
              colnames(generator)=rownames(generator)
            } else if(!setequal(rownames(generator),colnames(generator)))  colnames(generator)=rownames(generator) #fix when different
            if(missing(states)) states=rownames(generator) #assign
            if(missing(byrow)) byrow=TRUE #set byrow as true by default
            if(missing(name)) name="Unnamed Markov chain"  #generic name to the object
            callNextMethod(.Object, states = states, byrow = byrow, generator=generator,name=name,...)
          }
)

#returns states of the ctmc
setMethod("states","ctmc", 
          function(object) {
            out <- object@states
            return(out)
          }
)

#returns states of the ctmc
setMethod("dim","ctmc", 
          function(x) {
            out <- nrow(x@generator)
            return(out)
          }
)

setValidity("ctmc",
            function(object) {
              check<-NULL
              # performs a set of check whose results are saved in check
              if (.isGenRcpp(object@generator)==FALSE) check <- "Error! Not a generator matrix" 
              if (object@byrow==TRUE) {
                if(any(round(rowSums(object@generator),5)!=0)) check <- "Error! Row sums not equal to zero"
              } else {
                if(any(round(colSums(object@generator),5)!=0)) check <- "Error! Col sums not equal to zero"
              } 
              if (nrow(object@generator)!=ncol(object@generator)) check <- "Error! Not squared matrix" #check if squalre matrix
              if (!setequal(colnames(object@generator),object@states)) check <- "Error! Colnames <> states" #checks if 
              if (!setequal(rownames(object@generator),object@states)) check <- "Error! Rownames <> states"
              if ( is.null(check) ) return(TRUE) else return(check)
            }
)

.ctmcEigen<-function(matr, transpose=TRUE)
{
  # Function to extract eigenvalues, core of get steady states 
  #
  # Args:
  # matr: the matrix to extract
  # transpose:  boolean indicating whether the matrx shall be transpose
  #
  # Results:
  # a matrix / vector
  if (transpose) tMatr <- t(matr) else tMatr <- matr #trasposing
  eigenResults <- eigen(x=tMatr,symmetric=FALSE) #perform the eigenvalue extraction
  onesIndex <- which(round(eigenResults$values,3)==1) #takes the one eigenvalue
  #do the following: 1:get eigenvectors whose eigenvalues==1
  #2: normalize
  if (length(onesIndex)==0) {
    warning("No eigenvalue = 1 found - the embedded Markov Chain must be irreducible, recurrent")
    return(NULL)
  }
  if(length(onesIndex) > 1){
    warning("Eigenvalue = 1 multiplicity > 1! - the embedded Markov Chain must be irreducible, recurrent")
    return(NULL)
  }
  if (transpose==TRUE)
  {
    eigenTake <- as.matrix(t(eigenResults$vectors[,onesIndex])) 
    if(rowSums(Im(eigenTake)) != 0){
      warning("Eigenvector corresponding to largest eigenvalue has a non-zero imaginary part - the embedded Markov Chain must be irreducible, recurrent")
      return(NULL)
    }
    out <- eigenTake
  } else {
    eigenTake <- as.matrix(eigenResults$vectors[,onesIndex]) 
    if(colSums(Im(eigenTake)) != 0){
      warning("Eigenvector corresponding to largest eigenvalue has a non-zero imaginary part - the embedded Markov Chain must be irreducible, recurrent")
      return(NULL)
    }
    out <- eigenTake
  }
  return(out)
}

setMethod("steadyStates","ctmc", 
          function(object) {
            transposeYN <- FALSE
            if(object@byrow==TRUE) transposeYN <- TRUE		
            transMatr <- generatorToTransitionMatrix(object@generator, byrow = object@byrow)
            out<-.ctmcEigen(matr=transMatr, transpose=transposeYN) 
            if(is.null(out)) {
              warning("Warning! No steady state")
              return(NULL)
            }
            if(transposeYN==TRUE) { 
              colnames(out) <- object@states
            } else {
              rownames(out) <- object@states
            }
            out <- - out / diag(object@generator)
            if(transposeYN==TRUE){
              out <- out / rowSums(out)
            }
            else{
              out <- out / colSums(out)
            }
            return(out)
          }
)



# internal function for plotting ctmc object using igraph
.getNetctmc <- function(object, round = FALSE) {
  # function to get the graph adjacency object to plot and export to igraph
  #
  # Args: 
  # object: a ctmc object
  # round: boolean to round
  #
  # Returns:
  #
  # a graph adjacency
  
  if (object@byrow == FALSE) {
    object <- t(object)
  }
  
  #gets the generator matrix
  matr <- object@generator * 100
  if(round == TRUE) {
    matr <- round(matr, 2)
  }
  
  net <- graph.adjacency(adjmatrix = matr, weighted = TRUE, mode = "directed")
  return(net)
}


setMethod("plot",signature(x="ctmc",y="missing"),
          function(x,y,package = "igraph",...){
            switch(package,
                   diagram = {
                     if (requireNamespace("diagram", quietly = TRUE)) {
                       .plotdiagram(object = x, ...)
                     } else {
                       netMc <- .getNetctmc(object = x, round = TRUE)
                       edgeLabel <- round(E(netMc)$weight / 100, 2)
                       plot.igraph(x = netMc, edge.label = edgeLabel, ...)
                     }
                   },
                   
                   DiagrammeR = {
                     if (requireNamespace("DiagrammeR", quietly = TRUE)) {
                       .plotDiagrammeR(object = x, ...)
                     } else {
                       netMc <- .getNetctmc(object = x, round = TRUE)
                       edgeLabel <- round(E(netMc)$weight / 100, 2)
                       plot.igraph(x = netMc, edge.label = edgeLabel, ...)
                     }
                   },
                   {
                     netMc <- .getNetctmc(object = x,round = TRUE)
                     edgeLabel <- round(E(netMc)$weight / 100, 2)
                     plot.igraph(x = netMc, edge.label = edgeLabel, ...)
                   })
          }
          )



#' An S4 class for representing Imprecise Continuous Time Markovchains
#' 
#' @slot states a vector of states present in the ICTMC model
#' @slot Q matrix representing the generator demonstrated in the form of variables
#' @slot range a matrix that stores values of range of variables
#' @slot name name given to ICTMC
#' 
ictmc <- setClass("ictmc",
                  slots = list(states = "character", Q = "matrix",
                               range = "matrix", name = "character")
                  )




setMethod("initialize",
          signature(.Object = "ictmc"),
          function (.Object, states, Q, range, name, ...) {
            
            
            if(missing(Q)) Q=matrix(data=c(-1, 1, 1, -1), #create a naive matrix
                                                    nrow=2,
                                                    byrow=TRUE, 
                                                    dimnames=list(c("n", "y"), c("n", "y"))
            )
            
            
            if(missing(range)) range = matrix(c(1/52, 3/52, 1/2, 2),
                                              nrow = 2,
                                              byrow = 2)
            #if all names are missing it initializes them to "1", "2",...
            if(all(is.null(rownames(Q)), is.null(colnames(Q)))==TRUE) { 
              if(missing(states)) {
                nr=nrow(Q)
                stateNames<-as.character(seq(1:nr))
              } else {stateNames=states}
              
              rownames(Q)=stateNames
              colnames(Q)=stateNames
            } else if(is.null(rownames(Q))) { #fix when rownames null
              rownames(Q)=colnames(Q)
            } else if(is.null(colnames(Q))) { #fix when colnames null
              colnames(Q)=rownames(Q)
            } else if(!setequal(rownames(Q),colnames(Q)))  colnames(Q)=rownames(Q) #fix when different
            if(missing(states)) states=rownames(Q) #assign
            
            if(missing(name)) name="Unnamed imprecise CTMC"  #generic name to the object
            callNextMethod(.Object, states = states, Q = Q, range=range,name=name,...)
          }
          
)




setValidity("ictmc",
            function(object) {
              check<-NULL
              # performs a set of check whose results are saved in check
              if (.isGenRcpp(object@Q)==FALSE) check <- "Error! Not a generator matrix" 
              if(any(round(rowSums(object@Q),5)!=0)) check <- "Error! Row sums not equal to zero"
              if ( nrow(object@Q) != ncol(object@Q )) check <- "Error! Not squared matrix" #check if square matrix
              if ( !setequal(colnames(object@Q),object@states )) check <- "Error! Colnames <> states" 
              if ( !setequal(rownames(object@Q),object@states )) check <- "Error! Rownames <> states"
              
              
              if(nrow(object@range) != nrow(object@Q) && ncol(object@range) != 2) check <- "Error! dimension of range matrix not correct."
              for(i in 1:nrow(object@Q)){
                if( object@range[i,1] > object@range[i,2] ){
                  check <- "Error, improper values set in range matrix."
                }
                  
              }
              if(min(object@range) < 0){
                check <- "Error, values in the range matrix should be greater than zero."
              }
              
              
              if ( is.null(check) ) return(TRUE) else return(check)
            }
)






