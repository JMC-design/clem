;;;; File: defmatrix.cl
;;;; Author: Cyrus Harmon
;;;; 
;;;; This file contains definitions for typed matrices. Typed
;;;; matrices have elements that are of a single type (although
;;;; this type can have mutliple subtypes; even a t-matrix where
;;;; each of the items is of type t can offer substantial
;;;; performance gains, at least on SBCL).
;;;;

(in-package :clem)

;;; forward class definitions to keep things going for the moment
;;; these should go away once the MOP stuff is done.
;(defclass integer-matrix () ())
;(defclass float-matrix () ())

;;; Also taken from KMR's clsql package
(declaim (inline delistify))
(defun delistify (list)
  "Some MOPs, like openmcl 0.14.2, cons attribute values in a list."
  (if (and (listp list) (null (cdr list)))
      (car list)
      list))

(defmacro with-typed-matrix-vals ((m element-type specialized-array a) &body body)
  `(let ((,a (matrix-vals ,m)))
     ,(when specialized-array
	    `(declare 
	      (type (simple-array ,element-type (* *)) ,a)))
     ,@body))

(defmacro with-untyped-matrix-vals ((m element-type specialized-array a) &body body)
  (declare (ignore element-type specialized-array))
  `(let ((,a (matrix-vals ,m)))
     ,@body))

(defmacro with-matrix-vals ((m element-type a) &body body)
  `(if (equal ',element-type (element-type (class-of ,m)))
       (with-typed-matrix-vals (,m ,element-type t ,a)
	 ,@body)
       (with-untyped-matrix-vals (,m ,element-type nil ,a)
	 ,@body)))
	 
(defmacro with-map-range (m element-type startr endr startc endc (a i j) &body body)
  `(with-matrix-vals (,m ,element-type ,a)
     (do ((,i ,startr (1+ ,i)))
	 ((> ,i ,endr))
       (declare (dynamic-extent ,i) (type fixnum ,i))
       (do ((,j ,startc (1+ ,j)))
	   ((> ,j ,endc))
	 (declare (dynamic-extent ,j) (type fixnum ,j))
	 ,@body))))

;;; FIXME
;;; Change with-matrix-range-do to take matrix-type instead of element-type
;;; and specialized-array and use the metaclass to get this information.
;;; Can't just do this at runtime, unfortunately.

(defmacro with-matrix-range-do (matrix-class m n p startr endr startc endc (a b c i j) &body body)
  (let ((mat-class (if (typep matrix-class 'class)
		       matrix-class
		       (find-class matrix-class))))
    (let ((element-type (element-type mat-class)))
      `(with-matrix-vals (,m ,element-type ,a)
	 (with-matrix-vals (,n ,element-type ,b)
	   (with-matrix-vals (,p ,element-type ,c)
	     (do ((,i ,startr (1+ ,i)))
		 ((> ,i ,endr))
	       (declare #-sbcl (dynamic-extent ,i) (type fixnum ,i))
	       (do ((,j ,startc (1+ ,j)))
		   ((> ,j ,endc))
		 (declare #-sbcl (dynamic-extent ,j) (type fixnum ,j))
		 ,@body))))))))


;;; for the moment we're ignoring the specialized-array flag in
;;; theory, we could use this to allow for arrays of non-specialized
;;; types like integer, real or number, but for now we don't call
;;; any of these macros to generate specialized functions so
;;; we just get the generic version. consider removing this flag.
(defmacro defmatrixtype (type direct-superclasses &key 
			 (element-type 'double-float)
			 (accumulator-type 'double-float)
			 (initial-element 0)
			 (specialized-array nil)
			 minval maxval
			 (val-format "~4,9F"))
  (declare (ignore specialized-array))
  (unless direct-superclasses (setf direct-superclasses '(matrix)))
  `(progn
     (defclass ,type ,direct-superclasses
       ((initial-element :accessor initial-element :initarg :initial-element :initform ,initial-element))
       (:metaclass standard-matrix-class)
       (:element-type ,(delistify element-type))
       (:accumulator-type ,(delistify accumulator-type))
       (:val-format ,(delistify val-format))
       (:minval ,(if (symbolp minval) (symbol-value minval) minval))
       (:maxval ,(if (symbolp maxval) (symbol-value minval) maxval)))))

(defmacro defmatrixfuncs (type &key 
			  (element-type 'double-float)
			  (accumulator-type 'double-float)
			  (specialized-array nil)
			  minval maxval)
  `(progn
     (defmethod mref ((m ,type) (row fixnum) (col fixnum))
       (with-typed-matrix-vals (m ,element-type t a)
	 (aref a row col)))

     (defmethod (setf mref) (v (m ,type) (row fixnum) (col fixnum))
       (with-typed-matrix-vals (m ,element-type t a)
	 (setf (aref a row col) v)))

     (defgeneric ,(ch-util:make-intern (concatenate 'string "array->" (symbol-name type))) (a))
     (defmethod ,(ch-util:make-intern (concatenate 'string "array->" (symbol-name type))) ((a array))
       (array->matrix a :matrix-class ',type))
     
     (defmethod sample-variance-range ((m ,type) (startr fixnum) (endr fixnum) (startc fixnum) (endc fixnum))
       (let ((acc (coerce 0 ',accumulator-type)))
	 (let ((mu (mean-range m startr endr startc endc)))
	   (let ((musq (* mu mu)))
	     (with-map-range m ,element-type startr endr startc endc (a i j)
	       (incf acc (- (* (aref a i j) (aref a i j)) musq)))))
	 (double-float-divide acc (1- (count-range startr endr startc endc)))))
     
     (defmethod set-val ((m ,type) i j v &key (coerce t))
      (declare (fixnum i j))
       (setf (aref (matrix-vals m) i j) 
	     (if coerce
		 (coerce v (element-type (class-of m)))
		 v)))

     (defmethod fit ((m ,type) v)
       (declare (ignore m))
       ,(if (subtypep element-type 'real)
            (if maxval
                `(if (> v ,maxval)
                     ,maxval
                     ,(if minval `(if (< v ,minval) ,minval v) `v))
                (if minval `(if (< v ,minval) ,minval v) `v))
            `v))
     
     (defmethod set-val-fit ((m ,type) i j v &key (truncate nil))
       (set-val m i j (coerce 
		       ,(if (and (subtypep element-type 'real) minval maxval)
			    `(cond ((< v ,minval) ,minval)
				   ((> v ,maxval) ,maxval)
				   (t (if truncate (truncate v) v)))
			    `(if truncate (truncate v) v))
		       (element-type (class-of m)))))
     
     (defmethod map-set-val ((m ,type) f)
       (destructuring-bind (rows cols) (mapcar #'1- (dim m))
	 (declare (dynamic-extent rows cols) (fixnum rows cols))
	 (with-map-range m ,element-type 0 rows 0 cols (a i j)
	   (setf (aref a i j) (funcall f (aref a i j)))))
       m)
     
     (defgeneric ,(ch-util:make-intern (concatenate 'string "random-" (symbol-name type))) (rows cols &key max))
     (defmethod ,(ch-util:make-intern (concatenate 'string "random-" (symbol-name type))) (rows cols &key (max nil))
       (let ((a (make-instance ',type :rows rows :cols cols)))
	 (map-set-val-fit a #'(lambda (x) (declare (ignore x))
				      (random
				       (if max (coerce max ',element-type)
					   (if ,maxval ,maxval 255)))))
	 a))
     
     (defmethod normalize ((u ,type) &key (normin) (normax))
       (let ((min (min-val u))
	     (max (max-val u))
	     (nmin (if normin normin (if ,minval ,minval 0)))
	     (nmax (if normax normax (if ,maxval ,maxval 255))))
	 (let ((slope (double-float-divide (- nmax nmin)  (- max min))))
	   (map-set-val-fit u #'(lambda (x) (+ nmin (* slope (- x min))))))))
     
     (cond ((and (find-class 'integer-matrix nil)
		 (member (find-class 'integer-matrix) (sb-mop::class-precedence-list (find-class ',type))))
	    (defmethod scalar-divide-row ((m ,type)  k q)
	      (with-typed-matrix-vals (m ,element-type ,specialized-array a)
		(dotimes (j (cols m))
		  (setf (aref a k j) (fit m (truncate (/ (aref a k j) q))))))
	      m)
	    (defmethod scalar-mult-row ((m ,type) k q)
	      (with-typed-matrix-vals (m ,element-type ,specialized-array a)
		(dotimes (j (cols m))
		  (setf (aref a k j) (fit m (truncate (* (aref a k j) q))))))
	      m))
	   ((and (find-class 'float-matrix nil)
		 (member (find-class 'float-matrix) (sb-mop::class-precedence-list (find-class ',type))))
	    (defmethod scalar-divide-row ((m ,type)  k q)
	      (with-typed-matrix-vals (m ,element-type ,specialized-array a)
		(dotimes (j (cols m))
		  (setf (aref a k j) (fit m (/ (aref a k j) q)))))
	      m)
	    (defmethod scalar-mult-row ((m ,type) k q)
	      (with-typed-matrix-vals (m ,element-type ,specialized-array a)
		(dotimes (j (cols m))
		  (setf (aref a k j) (fit m (* (aref a k j) q)))))
	      m)))
     
     ))


(defmacro def-move-element (type-1 type-2)
  (let ((element-type-1 (element-type (find-class `,type-1)))
	(element-type-2 (element-type (find-class `,type-2))))
    `(progn
       (defmethod move-element
	   ((m ,type-1) i1 j1 (n ,type-2) i2 j2)
	 (with-matrix-vals (m ,element-type-1 a)
	   (with-matrix-vals (n ,element-type-2 b)
	     (setf (aref b i2 j2)
		   ,(if (eql element-type-1 element-type-2)
			`(aref a i1 j1)
			`(coerce (aref a i1 j1) ',element-type-2)))))))))

(defmacro maybe-coerce (val type-1 type-2)
  (if (eql type-1 type-2)
      val
      `(coerce ,val ',type-2)))

(defmacro maybe-truncate (val type-1 type-2)
  (if (and (subtypep type-2 'integer)
	   (subtypep type-1 'float))
      `(nth-value 0 (truncate ,val))
      `(maybe-coerce ,val ,type-1 ,type-2)))

