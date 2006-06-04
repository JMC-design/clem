((:P
  #.(progn
      (in-package :clem)
      #.(smarkup::enable-quote-reader-macro)
      (markup::setup-headings)
      nil)
  (:markup-metadata
   (:copyright
    "Copyright 2006, Cyrus Harmon. All Rights Reserved.")
   (:title
    "CLEM Matrix Performance")
   (:author "Cyrus L. Harmon")
   (:bibtex-database
    "(\"asdf:/ch-bib/lisp\" \"asdf:/ch-bib/bio\" \"asdf:/ch-bib/stat\" \"asdf:/ch-bib/vision\")")
   (:bibtex-style "Science"))
  (:html-metadata (:htmlcss "simple.css")))
 
 (:h1 "CLEM Performance")
 
 (:h2 "Introduction")

 (:p #q{Common Lisp is a high-level language that is a modern-day
     member of the LISP family of languages. Common Lisp can be
     either interpreted or compiled, or both, depending on the
     implementation and modern compilers offer the promise of
     performance on the order of that achieved by C and fortran
     compilers. CLEM is a matrix math package for Common Lisp that
     strives to offer high-performance matrix math routines, written
     in Common Lisp. Common Lisp has a sophisticated type system and
     it is a goal of CLEM to offer matrix representation and
     opreations that exploit the features of this type
     system. Furthermore, Common Lisp has a sophisticated object
     model, the Common Lisp Object System (CLOS), and CLEM uses
     features of CLOS and its companion metaobject system, the
     Meta-object Protocol (MOP) to define its classes, objects and
     methods.})

 (:p #q{Common Lisp implementations vary greatly in their
     peformance, but the Common Lisp standard provides an
     infrastructure for high-performance-capable implementations
     to generate efficient code through the use of compiler
     declarations of types and optimization settings. Lisp
     implementations are free to compile lisp code to native
     machine code, rather than either interpreting the lisp code
     on the fly, or compiling the code to a byte-code
     representation, that is then executed by a virtual
     machine. This suggests that, subject to the limits placed on
     the output by the common lisp language and to the
     implementation details of the particular lisp system, a lisp
     environment should be able to produce code that approaches
     the speed and efficiency of other compiled languages. SBCL
     is a Common Lisp implementation that compiles to native code
     and has a sophisticated compiler called, somewhat
     confusingly, Python, although the Python compiler predates
     the Python interpreted language by many years. SBCL's compiler
     uses type and optimization declarations to generate efficient
     code by producing optimized routines that are specific to the
     declared types, often representing data in an "unboxed" format,
     ideally one that matches the type representation handled directly
     by the CPU. One of CLEM's main goals is to provide efficient
     matrix operations that utilize the capabilities of the lisp
     compiler to generate efficient code.})
 
 (:h3 #q{Boxed and Unboxed Representation of Lisp Data Objects})

 (:h3 #q{Avoiding Unneccessary Memory Allocation}) 
 
 (:h1 #q{CLEM Design Goals})
 
 (:h2 #q{CLEM Implementation Choices})
 
 (:h1 #q{Matrix Data Representation})
 
 (:p #q{What options do we have for storing matrix data? Main choices
     are lisp arrays or an external block of memory. Are there other
     options here?})
 
 (:h2 #q{Reification of Matrix Data Objects})
 
 (:p #q{Defering, for a moment, the question of what form the
     actual matrix data will take, let us consider the form of
     the matrix object itself. It could be the object that
     represents the data directly, or it could be an object, such
     as an instance of a class or struct, that contains a
     reference to the object that holds the data. In a sense, the
     simplest approach to providing matrix arithmetic operations
     is just to use common lisp arrays both to hold the data and
     to be the direct representation of the matrix object. The
     CLEM design assumes that there is additional data, besides
     the data values stored in the array, or what have you, that
     will be needed and that just using a lisp array as the
     matrix itself is insufficient.})

 (:h2 #q{Common Lisp Arrays})
 
 (:p #q{Lisp arrays have the advantage that they are likely to
     take advantage of the lisp type system. Yes, an
     implementation may choose to ignroe this information, or
     continue to produce the same code as it would for untyped
     arrays, but a sufficently smart compiler, such as Python,
     should use the array type information to produce efficient
     code. Of course this also means that in order to get this
     efficiency we have to provide this type information to the
     compiler. As we try to modularize various pieces, it is
     often the case that one would like to have generic code that
     can work on matrices of any type. It these cases, additional
     measures may be needed to coax the compiler into generating
     efficient code, while doing so in a generic manner.})

 (:h3 #q{One-dimensional or Multi-dimensional Arrays?})

 (:p #q{One issue in dealing with lisp arrays is whether to use
     the lisp facilitty for multi-dimensional array. One argument
     in favor of native multi-dimensional arrays is that the
     compiler can generate efficent code to access data in
     certain multi-dimensional arrays, provided that this
     information is known and passed to the compiler at
     compile-time. On the other hand, using one-dimensional
     arrays puts both the burden of and the flexibility of
     computing array indices on the matrix package.})

 (:h3 #q{What About Lists?})

 (:p #q{Lists are convenient for representing matrices in that
 the iteration functions can be used to traverse the elements of
 the matrix, yielding the famous trivial transpose operation
 using mapcar and list. However, lists aren't designed for
 efficient random access and are a poor choice for representing
 anything but trivially small matrices.})

 (:h #q{Other Blocks of Memory})

 (:p #q{It is worth mentioning the possibility of other approaches,
 such as an external block of memory, perhaps allocated with either
 non-standard routines of the lisp system, or via a foreign-function
 interface, and to determine the offsets into this block of memory,
 coerce the contents to a given lisp type and obtain the results. This
 approach is used by some libraries that use clem, such as ch-image,
 to access matrix/array data stored in memory in a non-native-lisp
 form, such as matlisp matrices (which are really BLAS/LAPACK
 matrices), fftw matrices, and arrays of data from TIFF images. While
 this is nice to be able to do, it is unlikely to be practical for
 storing matrix data, given the alternative of using lisp
 arrays. Coercing of the contents of the matrix to lisp types is
 done for us by optimized code in the compiler. It is unlikely that we
 would be able to do a better job of this than the compiler. This
 approach is useful for conversion of matrix data to other in-memory
 formats, but unlikely to be useful for the typed lisp matrices for
 which CLEM is designed. If we were to go this route, it would make
 sense to use other, optimized, code libraries for operating on this
 data, and this is what matlisp does, handing these blocks of memory
 off to BLAS/LAPACK for processing in highly-optimized routines
 written in C, Fortran or Assembly Language. })

 (:h1 #q{Matrix Data Access})
 
 (:h2 #q{Now that we have chosen a matrix representation, how do we
      access the data in it?})
 
 (:h2 #q{Slow and Fast Data Access Paths})
 
 (:h2 #q{Flexibility})
 
 (:h3 #q{Resizing Matrices})
 
 (:h3 #q{Matrix Index "Recycling"})
 
 (:h2 #q{Macros})
 
 (:h2 #q{Compiler Macros})
 
 (:h2 #q{SBCL-specific Compiler Features})
 
 (:h3 #q{defknown/deftransform/defoptimizer})
 
 (:h1 #q{Benchmarks})
 
 (:h2 #q{Adding two matrices})
 
 (:p #q{First, we define some test matrices:})
 
 (:lisp
  #q{
  (defparameter b1 (make-array '(1024 1024)
                               :element-type 'double-float
                               :initial-element 1.0d0
                               :adjustable nil
                               :fill-pointer nil))
  
  (defparameter b2 (make-array '(1024 1024)
                               :element-type 'double-float
                               :initial-element 1.0d0
                               :adjustable nil
                               :fill-pointer nil))
  
  (defparameter b3 (make-array '(1024 1024)
                               :element-type 'double-float
                               :initial-element 1.0d0
                               :adjustable nil
                               :fill-pointer nil))
  })
 
 (:p #q{Now, our function to add the two arrays:})
 
 (:lisp
  #q{
  (defun bench/add-matrix/aref (a1 a2 a3)
    (destructuring-bind (rows cols)
        (array-dimensions a1)
      (dotimes (i rows)
        (dotimes (j cols)
          (setf (aref a3 i j) (+ (aref a1 i j) (aref a2 i j)))))))
  
  })
 
 
 (:p #q{Now, we time how long it takes to run bench/addmatrix/aref:})
 
 
 (:lisp
  #q{(ch-util:time-to-string (bench/add-matrix/aref b1 b2 b3))})

#+nil(:BIBLIOGRAPHY))

