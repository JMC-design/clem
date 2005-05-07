;;; -*- Mode: lisp; outline-regexp: ";;;;;*"; indent-tabs-mode: nil -*-;;;
;;;
;;; file: matrix.cl
;;; author: cyrus harmon
;;; time-stamp: Fri Apr 23 13:44:30 EDT 2004
;;;

;;;
;;; This file contains the core of the matrix common-lisp class.
;;; This class represents matrices, vectors and scalars, somewhat.

;;;
;;; 2004-06-17 - Need to decouple the notion of the shape of the matrix
;;;              e.g. matrix, col-vec, row-vec from the type of the
;;;              matrix or we're going to have n^2 kinds of matrices
;;;              we'll need to make
;;;

;;; 2004-05-08 - Scrap that last thought. I'm going to make 2-d
;;;              arrays work and assume that the compiler is smarter
;;;              then I am in making reasonable 2-d arrays.
;;;
;;; 2004-04-23 - The big problem with this, so far, is
;;;              that my LISP implementation seems to use a lot of
;;;              memory to access 2-d arrays. It seems better With
;;;              one-d arrays, so I'm going to try to change this all
;;;              to simple arrays of simple arrays and see if things
;;;              get better.
;;;
;;;


(in-package :clem)

(define-condition matrix-condition ()
  ())

(define-condition matrix-error (simple-error matrix-condition)
  ())

(deftype index-type ()
  '(integer 0 #.(1- array-dimension-limit)))

(declaim (inline matrix-vals))
(defclass matrix ()
  ((m :accessor matrix-vals)
   (element-type :allocation :class :accessor element-type :initarg :element-type :initform 'double-float)
   (rows :accessor matrix-rows :initarg :rows :initform 1)
   (cols :accessor matrix-cols :initarg :cols :initform 1)
   (initial-element :accessor initial-element :initarg :initial-element :initform 0d0)
   (adjustable :accessor adjustable :initarg :adjustable :initform nil)
   (resizeable :accessor resizable :initform nil)
   (val-format :accessor val-format :initform "~4,9F"))
  (:metaclass standard-matrix-class)
  (:element-type 'double-float))

(defgeneric allocate-matrix-vals (object &key rows cols adjustable initial-element element-type))
(defmethod allocate-matrix-vals ((object matrix) &key rows cols adjustable initial-element element-type)
  (setf (slot-value object 'm)
	(make-array (list rows cols)
		    :adjustable adjustable
		    :initial-element initial-element
		    :element-type (element-type (class-of object))
		    )))
  
(defmethod shared-initialize :after
    ((object matrix) slot-names &rest initargs &key rows cols adjustable initial-element element-type)
  (declare (ignore slot-names initargs rows cols adjustable initial-element element-type))
  (allocate-matrix-vals object
                        :rows (slot-value object 'rows)
                        :cols (slot-value object 'cols)
                        :adjustable (slot-value object 'adjustable)                        
                        :initial-element (slot-value object 'initial-element)
                        :element-type (slot-value object 'element-type)))
(defun list-if (x)
  (if x (list x) x))

#+openmcl
(defun compute-class-precedence-list (class)
  (ccl:class-precedence-list class))

(defgeneric matrix-precedence-list (c)
  (:method ((c class))
    (let ((mpl (compute-class-precedence-list c))
	  (mc (find-class 'matrix)))
      (mapcan #'(lambda (x)
		  (if (subclassp x mc) (list-if x)))
              mpl)
      )))

(defgeneric closest-common-matrix-class (m1 &rest mr)
  (:method ((m1 matrix) &rest mr)
    (car (apply #'closest-common-ancestor
                (mapcar #'(lambda (x) (matrix-precedence-list (class-of x)))
                        (cons m1 mr))))
    ))

(defgeneric fit (m val))
(defmethod fit ((m matrix) val)
  (declare (ignore m))
  val)

(defgeneric fit-value (val m))
(defmethod fit-value (val (m matrix))
  (declare (ignore m))
  val)

(defgeneric dim (m))
(defmethod dim ((m matrix)) (array-dimensions (matrix-vals m)))

(defgeneric rows (m))
(defmethod rows ((m matrix)) (the fixnum (first (dim m))))

(defgeneric cols (m))
(defmethod cols ((m matrix)) (the fixnum (second (dim m))))

(defgeneric val (m i j))
(defmethod val ((m matrix) i j) (aref (matrix-vals m) i j))

(defgeneric set-val (m i j v &key coerce))
(declaim (inline set-val))
(defmethod set-val ((m matrix) i j v &key (coerce t))
  (setf (aref (matrix-vals m) i j)
	(if coerce
	    (coerce v (element-type m))
	    v)))

(defgeneric set-val-fit (m i j v &key truncate))
(defmethod set-val-fit ((m matrix) i j v &key (truncate nil))
  (set-val m i j (if truncate (truncate v) v)))


(defparameter *print-matrix-newlines* t)
(defparameter *print-matrix-float-format* nil)

(defgeneric print-range (m startr endr startc endc))
(defmethod print-range ((m matrix)
			(startr fixnum) (endr fixnum)
			(startc fixnum) (endc fixnum))
  (let ((val-format-spec (if *print-matrix-float-format*
                             *print-matrix-float-format*
                             (val-format m))))
    (format t "#[")
    (do ((i startr (1+ i)))
        ((> i endr))
      (unless (= i startr)
        (princ "; ")
        (if *print-matrix-newlines*
            (progn
              (format t "~&~2,0T"))))
      (do ((j startc (1+ j)))
          ((> j endc))
        (format t (if (= j startc)
                      val-format-spec
                      (util:strcat " " val-format-spec)) (val m i j))))
    (format t "]~&")))

(defgeneric print-matrix (m))
(defmethod print-matrix ((m matrix))
  (destructuring-bind (endr endc) (mapcar #'1- (dim m))
    (print-range m 0 endr 0 endc))
  m)

(defgeneric transpose (m))
(defmethod transpose ((m matrix))
  (destructuring-bind (rows cols) (dim m)
    (let ((tr (make-instance (class-of m) :rows cols :cols rows)))
      (dotimes (i rows)
	(dotimes (j cols)
	  (set-val tr j i (val m i j))))
      tr)))

(defgeneric mat-mult (a b))
(defmethod mat-mult ((a matrix) (b matrix))
  (destructuring-bind (ar ac) (dim a)
    (destructuring-bind (br bc) (dim b)
      (cond
       ((= ac br)
	(let* ((c (make-instance (class-of a) :rows ar :cols bc)))
	  (dotimes (i ar)
	    (dotimes (j bc)
	      (let ((v 0))
		(dotimes (r ac)
		  (incf v (* (val a i r) (val b r j))))
		(set-val c i j v))))
	  c))))))

(defgeneric mat-copy-into (a c &key truncate))
(defmethod mat-copy-into ((a matrix) (c matrix) &key (truncate))
  (destructuring-bind (m n) (dim a)
    (dotimes (i m)
      (dotimes (j n)
	(if truncate
	    (set-val-fit c i j (val a i j) :truncate truncate)
	    (set-val c i j (val a i j)))))
    c))

(defgeneric mat-copy-proto-dim (a m n))
(defmethod mat-copy-proto-dim ((a matrix) (m fixnum) (n fixnum))
  (make-instance (class-of a) :rows m :cols n))

(defgeneric mat-copy-proto (a))
(defmethod mat-copy-proto ((a matrix))
  (destructuring-bind (m n) (dim a)
    (make-instance (class-of a) :rows m :cols n)))

(defgeneric mat-copy (a &rest args))
(defmethod mat-copy ((a matrix) &rest args)
  (let ((c (mat-copy-proto a)))
    (apply #'mat-copy-into a c args)
    c))

(defgeneric mat-scalar-op (a b op))
(defmethod mat-scalar-op ((a matrix) (b matrix) op)
  (and (equal (dim a) (dim b))
       (destructuring-bind (m n) (dim a)
	 (let ((c (mat-copy a)))
	   (dotimes (i m c)
	     (dotimes (j n)
	       (set-val c i j (funcall op (val a i j) (val b i j)))))))))
	
(defgeneric mat-add (a b))
(defmethod mat-add ((a matrix) (b matrix))
  (mat-scalar-op a b #'+))

(defgeneric mat-subtr (a b))
(defmethod mat-subtr ((a matrix) (b matrix))
  (mat-scalar-op a b #'-))

(defgeneric swap-rows (a k l))
(defmethod swap-rows ((a matrix) k l)
  (let* ((da (dim a))
	 (n (second da)))
    (dotimes (j n)
      (let ((h (val a k j)))
	(set-val a k j (val a l j))
	(set-val a l j h)))))

(defgeneric swap-cols (a k l))
(defmethod swap-cols ((a matrix) k l)
  (let* ((da (dim a))
	 (m (first da)))
    (dotimes (i m)
      (let ((h (val a i k)))
	(set-val a i k (val a i l))
	(set-val a i l h)))))

(defgeneric map-col (a k f))
(defmethod map-col ((a matrix) k f)
  (destructuring-bind (m n) (dim a)
    (declare (ignore n))
    (dotimes (i m)
      (set-val a i k (funcall f (val a i k))))))

(defgeneric map-row (a k f))
(defmethod map-row ((a matrix) k f)
  (destructuring-bind (m n) (dim a)
    (declare (ignore m))
    (dotimes (j n)
      (set-val a k j (funcall f (val a k j))))))

(defparameter *scalar-ops*
  (list (list "mult" #'*)
	(list "divide" #'/)
	(list "double-float-divide" #'util:double-float-divide)
	(list "single-float-divide" #'util:single-float-divide)
	))

(defun def-scalar-row-op (name f)
  (eval (list 'defmethod
	      (util:make-intern (util:strcat "scalar-" name "-row"))
	      `((a matrix) k q)
	      `(map-row a k #'(lambda (x) (apply ,f (list x q))))
              `a)))

(defun def-scalar-col-op (name f)
  (eval (list 'defmethod
	      (util:make-intern (util:strcat "scalar-" name "-col"))
	      `((a matrix) k q)
	      `(map-col a k #'(lambda (x) (apply ,f (list x q))))
              `a)))

(defun def-scalar-ops (name f)
  (def-scalar-row-op name f)
  (def-scalar-col-op name f))

(mapcar #'(lambda (x)
	    (def-scalar-ops (car x) (cadr x)))
	*scalar-ops*)
	    
(defgeneric scalar-mult (m q))
(defmethod scalar-mult ((m matrix) q)
  (dotimes (i (first (dim m)) m)
    (scalar-mult-row m i q))
  m)

(defgeneric scalar-mult-copy (m q))
(defmethod scalar-mult-copy ((a matrix) q)
  (let ((m (mat-copy a)))
    (scalar-mult m q)))

(defgeneric scalar-divide (a q))
(defmethod scalar-divide ((a matrix) q)
  (dotimes (i (first (dim a)) a)
    (scalar-divide-row a i q))
  a)

(defgeneric scalar-divide-copy (a q))
(defmethod scalar-divide-copy ((a matrix) q)
  (let ((m (mat-copy a)))
    (scalar-divide m q)))

(defgeneric zero-matrix (j &optional k))
(defmethod zero-matrix ((j fixnum) &optional (k j))
  (make-instance 'matrix :rows j :cols k))

(defgeneric identity-matrix (k))
(defmethod identity-matrix ((k fixnum))
  (let ((a (zero-matrix k)))
    (dotimes (i k a)
      (set-val a i i 1d0))))

(defgeneric concat-matrix-cols (a b &key matrix-type))
(defmethod concat-matrix-cols ((a matrix) (b matrix) &key matrix-type)
  (let ((da (dim a)) (db (dim b)))
    (cond
      ((equal (first da) (first db))
       (let ((c (make-instance (if matrix-type
				   matrix-type
				   (class-of a)) :rows (first da) :cols (+ (second da) (second db)))))
	 (let  ((m (first da))
		(n (second da))
		(q (second db)))
	   (dotimes (i m)
	     (dotimes (j n)
	       (set-val c i j (val a i j) :coerce t)))
	   (dotimes (i m)
	     (dotimes (j q)
	       (set-val c i (+ j n) (val b i j) :coerce t))))
	 c))
      (t nil))))

(defgeneric subset-matrix-cols (a x y &key (matrix-type)))
(defmethod subset-matrix-cols ((a matrix) x y &key (matrix-type))
  (let ((da (dim a)))
    (cond
     ((< x y)
      (let* ((m (first da))
	     (n (- y x))
	     (c (make-instance (if matrix-type
				   matrix-type
				   (class-of a)) :rows (first da) :cols (- y x))))
	(dotimes (i m)
	  (dotimes (j n)
	    (set-val c i j (val a i (+ j x)))))
	c))
     (t nil))))

(defgeneric get-first-non-zero-row-in-col (a j &optional start))
(defmethod get-first-non-zero-row-in-col ((a matrix) j &optional (start 0))
  (let ((n (first (dim a))))
    (do ((i start (+ i 1)))
	((or (= i n)
	     (not (= (val a i j) 0)))
	 (if (= i n)
	     nil
	   i)))))

(defgeneric invert-matrix (a))
(defmethod invert-matrix ((a matrix))
  (let* ((n (second (dim a)))
	 (c (concat-matrix-cols a (identity-matrix n) :matrix-type 'double-float-matrix)))
    (do*
	((y 0 (+ y 1)))
	((or (= y n) (not c)))
      (let ((z (get-first-non-zero-row-in-col c y y)))
	(cond
	 ((not z) (setf c nil))
	 (t
	  (if (> z y)
	      (swap-rows c y z))
	  (scalar-divide-row c y (val c y y))
	  (do*
	      ((i 0 (+ i 1)))
	      ((= i n))
	    (unless (= i y)
	      (let ((k (val c i y)))
		(dotimes (j (* n 2))
		  (set-val c i j (+ (val c i j)
				    (* (- k) (val c y j))))))))))))
    (unless (not c)
      (subset-matrix-cols c n (+ n n) :matrix-type 'double-float-matrix))))

(defgeneric transpose-matrix (a))
(defmethod transpose-matrix ((a matrix))
  (let* ((da (dim a))
	 (m (first da))
	 (n (second da))
	 (c (make-instance (class-of a) :rows n :cols m)))
    (dotimes (i m)
      (dotimes (j n)
	(set-val c j i (val a i j))))
    c))

(defgeneric add-row (m &key values initial-element)
  (:method ((m matrix) &key values initial-element)
    (if (adjustable m)
	(progn
	  (if (null initial-element)
	      (setf initial-element (initial-element m)))
	  (let ((d (dim m)))
	    (setf (matrix-vals m)
		  (adjust-array (matrix-vals m) (list (+ 1 (first d)) (second d))
				:initial-element initial-element))
	    (if values
		(do
		 ((l values (cdr l))
		  (i 0 (+ i 1)))
		 ((not l))
		  (set-val m (first d) i (car l))))))
	(error 'matrix-error :message "Tried to add-row to non-adjustable matrix ~A" m))))

(defgeneric add-col (m &key values initial-element)
  (:method ((m matrix) &key values initial-element)
    (if (adjustable m)
	(progn
	  (if (null initial-element)
	      (setf initial-element (initial-element m)))
	  (let ((d (dim m)))
	    (setf (matrix-vals m)
		  (adjust-array (matrix-vals m) (list (first d) (+ 1 (second d)))
				:initial-element initial-element))
	    (if values
		(do
		 ((l values (cdr l))
		  (i 0 (+ i 1)))
		 ((not l))
		  (set-val m i (second d) (car l))))))
	(error 'matrix-error :message "Tried to add-col to non-adjustable matrix ~A" m))))

(defgeneric reshape (m rows cols &key initial-element)
  (:method ((m matrix) rows cols &key initial-element)
    (if (adjustable m)
	(progn
	  (if (null initial-element)
	      (setf initial-element (initial-element m)))
	  (setf (matrix-vals m)
		(adjust-array (matrix-vals m) (list rows cols)
			      :initial-element initial-element)))
	(error 'matrix-error :message "Tried to reshape non-adjustable matrix ~A" m))))

(defgeneric horzcat (m1 &rest mr)
  (:method ((m1 matrix) &rest mr)
    (let ((rows (apply #'max (mapcar #'rows (cons m1 mr))))
          (cols (apply #'+ (mapcar #'cols (cons m1 mr)))))
      (let ((z (make-instance (apply #'closest-common-matrix-class m1 mr)
                              :rows rows
                              :cols cols)))
        (let ((coff 0))
          (dolist (x (cons m1 mr))
            (print x)
            (map-set-range z 0 (- (rows x) 1) coff (+ coff (- (cols x) 1))
                           #'(lambda (v i j) (declare (ignore v)) (val x i (- j coff))))
            (incf coff (cols x))
            ))
        z))))

(defgeneric vertcat (m1 &rest mr)
  (:method ((m1 matrix) &rest mr)
    (let ((rows (apply #'+ (mapcar #'rows (cons m1 mr))))
          (cols (apply #'max (mapcar #'cols (cons m1 mr)))))
      (let ((z (make-instance (apply #'closest-common-matrix-class m1 mr)
                              :rows rows
                              :cols cols)))
        (let ((roff 0))
          (dolist (x (cons m1 mr))
            (print x)
            (map-set-range z roff (+ roff (- (rows x) 1)) 0 (- (cols x) 1)
                           #'(lambda (v i j) (declare (ignore v)) (val x (- i roff) j)))
            (incf roff (rows x))
            ))
        z))))

(defmethod pad-matrix ((m matrix))
  (cond
    ((> (rows m) (cols m))
     (let ((delta (- (rows m) (cols m))))
       (horzcat (make-instance (class-of m)
                               :rows (rows m)
                               :cols (ceiling (/ delta 2)))
                m
                (make-instance (class-of m)
                               :rows (rows m)
                               :cols (floor (/ delta 2))))))
    ((> (cols m) (rows m))
     (let ((delta (- (cols m) (rows m))))
       (vertcat (make-instance (class-of m)
                               :rows (ceiling (/ delta 2))
                               :cols (cols m))
                m
                (make-instance (class-of m)
                               :rows (floor (/ delta 2))
                               :cols (cols m)))))))

(defmethod set-row ((m matrix) r values)
  (do
      ((l values (cdr l))
       (i 0 (+ i 1)))
      ((not l))
    (set-val m r i (car l))))

(defmethod set-col ((m matrix) c values)
  (do
      ((l values (cdr l))
       (i 0 (+ i 1)))
      ((not l))
    (set-val m i c (car l))))

(defmethod get-row-list ((m matrix) r &optional (start 0))
  (cond
   ((< start (second (dim m)))
    (cons (val m r start)
	  (get-row-list m r (+ 1 start))))
   (t nil)))

(defmethod get-col-list ((m matrix) c &optional (start 0))
  (cond
   ((< start (first (dim m)))
    (cons (val m start c)
	  (get-col-list m c (+ 1 start))))
   (t nil)))

(defmethod map-set-val ((a matrix) f)
  (destructuring-bind (m n) (dim a)
    (declare (dynamic-extent m n) (fixnum m n))
    (dotimes (i m)
      (declare (dynamic-extent i) (fixnum i))
      (dotimes (j n)
        (declare (dynamic-extent j) (fixnum j))
	(set-val a i j (funcall f (val a i j))))))
  a)

(defmethod map-set-val-fit ((a matrix) f &key (truncate t))
  (destructuring-bind (m n) (dim a)
    (declare (dynamic-extent m n) (fixnum m n))
    (dotimes (i m)
      (declare (dynamic-extent i) (fixnum i))
      (dotimes (j n)
        (declare (dynamic-extent j) (fixnum j))
	(set-val-fit a i j (funcall f (val a i j)) :truncate truncate))))
  a)

(defmethod map-set-val-copy ((a matrix) f)
  (destructuring-bind (ar ac) (dim a)
    (declare (dynamic-extent ar ac) (fixnum ar ac))
    (let* ((b (mat-copy-proto a)))
      (dotimes (i ar)
        (declare (dynamic-extent i) (fixnum i))
	(dotimes (j ac)
          (declare (dynamic-extent j) (fixnum j))
	  (set-val b i j (funcall f (val a i j)))))
      b)))

(defmethod map-range ((a matrix)
                      (startr fixnum)
                      (endr fixnum)
                      (startc fixnum)
                      (endc fixnum)
                      f)
  (declare (dynamic-extent startr endr startc endc)
	   (fixnum startr endr startc endc))
  (do ((i startr (1+ i)))
      ((> i endr))
    (declare (dynamic-extent i) (type fixnum i))
    (do ((j startc (1+ j)))
	((> j endc))
      (declare (dynamic-extent j) (type fixnum j))
      (funcall f (val a i j) i j))))

(defmethod map-set-range ((a matrix)
                          (startr fixnum)
                          (endr fixnum)
                          (startc fixnum)
                          (endc fixnum)
                          f)
  (declare (dynamic-extent startr endr startc endc)
	   (fixnum startr endr startc endc))
  (do ((i startr (1+ i)))
      ((> i endr))
    (declare (dynamic-extent i) (fixnum i))
    (do ((j startc (1+ j)))
	((> j endc))
      (declare (dynamic-extent j) (fixnum j))
      (set-val a i j (funcall f (val a i j) i j)))))

(defmethod random-matrix ((rows fixnum) (cols fixnum) &key
                          (matrix-class 'matrix)
                          (limit 1.0d0))
  (declare (dynamic-extent rows cols)
	   (fixnum rows cols))
  (let ((a (make-instance matrix-class :rows rows :cols cols)))
    (map-set-val a #'(lambda (x) (declare (ignore x)) (random limit)))
    a))

(defmethod min-range ((m matrix) (startr fixnum) (endr fixnum) (startc fixnum) (endc fixnum))
  (declare (dynamic-extent startr endr startc endc)
	   (fixnum startr endr startc endc))
  (let ((retval (val m startr startc)))
    (map-range m startr endr startc endc
	       #'(lambda (v i j)
		   (declare (ignore i j))
		   (setf retval (min retval v))))
    retval))

(defmethod max-range ((m matrix) (startr fixnum) (endr fixnum) (startc fixnum) (endc fixnum))
  (let ((retval (val m startr startc)))
    (map-range m startr endr startc endc
	       #'(lambda (v i j)
		   (declare (ignore i j))
		   (setf retval (max retval v))))
    retval))


(defmethod sum-range ((m matrix) (startr fixnum) (endr fixnum) (startc fixnum) (endc fixnum))
  (declare (dynamic-extent startr endr startc endc)
	   (fixnum startr endr startc endc))
  (let ((acc 0))
    (map-range m startr endr startc endc
	       #'(lambda (v i j)
		   (declare (ignore i j))
		   (incf acc v)))
    acc))

(defmethod sum ((m matrix))
  (destructuring-bind (mr mc) (dim m)
    (sum-range m 0 (- mr 1) 0 (- mc 1))))

(defmethod sum-square-range ((m matrix) (startr fixnum) (endr fixnum) (startc fixnum) (endc fixnum))
  (declare (dynamic-extent startr endr startc endc)
	   (fixnum startr endr startc endc))
  (let ((acc 0))
    (map-range m startr endr startc endc
	       #'(lambda (v i j)
		   (declare (ignore i j))
		   (incf acc (* v v))))
    acc))

(defmethod sum-square ((m matrix))
  (destructuring-bind (mr mc) (dim m)
    (sum-square-range m 0 (- mr 1) 0 (- mc 1))))

(defun count-range (startr endr startc endc)
  (* (1+ (- endr startr)) (1+ (- endc startc))))  

(defmethod mean-range ((m matrix) startr endr startc endc)
  (util:double-float-divide (sum-range m startr endr startc endc)
		(count-range startr endr startc endc)))


(defmethod mean ((m matrix))
  (destructuring-bind (mr mc) (dim m)
    (mean-range m 0 (- mr 1) 0 (- mc 1))))

(defmethod variance-range ((m matrix) startr endr startc endc)
  (declare (dynamic-extent startr endr startc endc)
	   (fixnum startr endr startc endc))
  (let ((mu (mean-range m startr endr startc endc)))
    (let ((musq (* mu mu)))
      (let ((ssr (sum-square-range m startr endr startc endc)))
	(let ((cr (count-range startr endr startc endc)))
	  (declare (fixnum cr))
	  (- (util:double-float-divide ssr cr)
	     musq))))))

(defmethod variance ((m matrix))
  (destructuring-bind (mr mc) (dim m)
    (variance-range m 0 (- mr 1) 0 (- mc 1))))

(defmethod sample-variance-range ((m matrix) startr endr startc endc)
  (let* ((acc 0)
	 (mu (mean-range m startr endr startc endc))
	 (musq (* mu mu)))
    (map-range m startr endr startc endc
	       #'(lambda (v i j)
		   (declare (ignore i j))
		   (incf acc (- (* v v) musq))))
    (util:double-float-divide acc (1- (count-range startr endr startc endc)))))

(defmethod sample-variance ((m matrix))
  (destructuring-bind (mr mc) (dim m)
    (sample-variance-range m 0 (- mr 1) 0 (- mc 1))))


(defmethod min-val ((m matrix))
  (let ((minval (val m 0 0)))
    (let ((d (dim m)))
      (dotimes (i (first d))
	(dotimes (j (second d))
	  (setf minval (min minval (val m i j))))))
    minval))

(defmethod max-val ((m matrix))
  (let ((maxval (val m 0 0)))
    (let ((d (dim m)))
      (dotimes (i (first d))
	(dotimes (j (second d))
	  (setf maxval (max maxval (val m i j))))))
    maxval))

(defmethod mat-square ((u matrix))
  (map-set-val-copy u #'(lambda (x) (* x x))))

(defmethod mat-square! ((u matrix))
  (map-set-val u #'(lambda (x) (* x x))))

(defmethod mat-sqrt ((u matrix))
  (map-set-val-copy u #'(lambda (x) (sqrt x))))

(defmethod mat-sqrt! ((u matrix))
  (map-set-val u #'(lambda (x) (sqrt x))))


(defmethod normalize ((u matrix) &key (normin) (normax) (truncate nil))
  (let ((min (min-val u))
	(max (max-val u))
	(nmin (if normin normin 0))
	(nmax (if normax normax 255)))
    (let ((slope (/ (- nmax nmin) (- max min))))
      (map-set-val-fit u #'(lambda (x) (+ nmin (* slope (- x min))))
		       :truncate truncate))))

(defmethod norm-0-255 ((u matrix))
  (normalize u :normin 0 :normax 255 :truncate t))

(defmethod norm-0-1 ((u matrix))
  (normalize u :normin 0 :normax 1 :truncate t))

(defmethod subset-matrix ((u matrix) startr endr startc endc)
  (destructuring-bind (ur uc) (dim u)
    (cond
     ((and (<= startr endr ur) (<= startc endc uc))
      (let* ((m (1+ (- endr startr)))
	     (n (1+ (- endc startc)))
	     (c (mat-copy-proto-dim u m n)))
	(dotimes (i m)
	  (dotimes (j n)
	    (set-val c i j (val u (+ i startr) (+ j startc)))))
	c))
     (t nil))))

(defmethod map-matrix ((a matrix) f)
  (destructuring-bind (m n) (dim a)
    (dotimes (i m)
      (dotimes (j n)
	(set-val a i j (funcall f a i j)))))
  a)

(defmethod map-matrix-copy ((a matrix) f)
  (destructuring-bind (m n) (dim a)
    (let* ((b (mat-copy-proto a)))
      (dotimes (i m)
	(dotimes (j n)
	  (set-val b i j (funcall f a i j))))
      b)))

(defmethod array->matrix ((a array) &key (matrix-class 'matrix))
  (let ((d (array-dimensions a))
	(m))
    (cond ((= (length d) 2)
	   (destructuring-bind (ar ac) d
	     (cond
	      ((and (= ar 1) (= ac 1))
	       (setf m (scalar (aref a 0 0))))
	      ((= ac 1)
	       (setf m (array->col-vector a)))
	      ((= ar 1)
	       (setf m (array->row-vector a)))
	      (t 
	       (setf m (make-instance matrix-class :rows ar :cols ac))
	       (let ((k 0))
		 (dotimes (i ar)
		   (dotimes (j ac)
		     (set-val m i j (aref a i j) :coerce t)
		     (incf k)))))))))
    m))

(defmethod trim-one ((m matrix) k)
  (destructuring-bind (mr mc) (dim m)
    (subset-matrix m k (- mr k 1) k (- mc k 1))))
