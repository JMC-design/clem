;;;
;;; file: matrixops.cl
;;; author: cyrus harmon
;;; time-stamp: Fri Apr 23 13:44:30 EDT 2004
;;;

;;;
;;; 2004-05-07 - This class contains matrix operations such as
;;;              gaussian-blur, gradient, etc...
;;;
;;;              Relies on the matrix package for matrix datatypes
;;;              and core functions such as discrete-convolve
;;;

(in-package :clem)


;;; discrete-convolve takes two matrices and returns
;;; a new matrix which is the convolution of the two matrices.
;;; To convolve, for each row,col of the matrix u, overlay matrix v
;;; the current cell and take the sum of the product of all of the
;;; u,v pairs. Note that v is rotated 180 degrees wrt u so that
;;; if we are calculating the value of (1,1) in the convolution of
;;; 3x3 matrices, the first number we would sum would be (0,0) x (2,2)
;;; not (0,0) x (0,0)

;;; discrete-convolve takes two matrices and returns
;;; a new matrix which is the convolution of the two matrices.
;;; To convolve, for each row,col of the matrix u, overlay matrix v
;;; the current cell and take the sum of the product of all of the
;;; u,v pairs. Note that v is rotated 180 degrees wrt u so that
;;; if we are calculating the value of (1,1) in the convolution of
;;; 3x3 matrices, the first number we would sum would be (0,0) x (2,2)
;;; not (0,0) x (0,0)


(defmethod discrete-convolve ((u matrix) (v matrix)
			      &key (truncate nil) (norm-v t)
			      (matrix-class nil))
  (declare (optimize (speed 3) (safety 0) (space 0)))
  ;;; ur, uc, vr, vc are the number of rows and columns in u and v
  (print 'unspecialized-discrete-convolve!)
  (destructuring-bind (ur uc) (dim u)
    (declare (dynamic-extent ur uc) (fixnum ur uc))
    (destructuring-bind (vr vc) (dim v)
      (declare (fixnum vr vc) (dynamic-extent vr vc))
      ;;; need a new matrix z to hold the values of the convolved matrix
      ;;; dim z should be dim u + dim v - 1
      (let ((zr (+ ur vr (- 1)))
	    (zc (+ uc vc (- 1))))
	(declare (fixnum zr zc) (dynamic-extent zr zc))
	(unless matrix-class
	  (setf matrix-class (type-of u)))
	(let ((z (make-instance matrix-class :rows zr :cols zc))
	      (uval (matrix-vals u))
	      (vval (matrix-vals v))
	      (vsum (sum v)))
	  (dotimes (i zr)
	    (let ((ustartr (max 0 (- i vr -1)))
		  (uendr (min (- ur 1) i))
		  (vstartr (- vr (max (- vr i) 1)))
		  (vendr (- vr (min (- zr i) vr))))
	      (dotimes (j zc)
		(let ((ustartc (max 0 (- j vc -1)))
		      (uendc (min (- uc 1) j))
		      (vstartc (- vc (max (- vc j) 1)))
		      (vendc (- vc (min (- zc j) vc)))
		      (acc 0))
		  (let ((normval (if (and norm-v (or (not (= vendr vendc 0))
						     (< vstartr (- vr 1))
						     (< vstartc (- vc 1))))
				     (let ((rsum (sum-range v vendr vstartr vendc vstartc)))
				       (if (not (= rsum 0))
					   (/ vsum rsum)
					 0))
				   nil)))
		    (do ((urow ustartr (1+ urow))
			 (vrow vstartr (1- vrow)))
			((> urow uendr))
		      (declare (fixnum urow vrow))
		      (declare (dynamic-extent urow vrow))
		      (do ((ucol ustartc (1+ ucol))
			   (vcol vstartc (1- vcol)))
			  ((> ucol uendc))
			(declare (fixnum ucol vcol))
			(declare (dynamic-extent ucol vcol))
			(let ((uv (val u urow ucol))
			      (vv (val v vrow vcol)))
			  (declare (dynamic-extent uv vv))
			  (incf acc (* uv vv))
			  )))
		    (if normval
			(setf acc (fit-value (* acc normval) z)))
		    (if truncate
			(set-val-fit z i j acc :truncate truncate)
			(set-val z i j acc)))))))
	  z)))))

(defmethod discrete-convolve-orig ((u matrix) (v matrix) &key (truncate))
  ;;; ur, uc, vr, vc are the number of rows and columns in u and v
  (destructuring-bind (ur uc) (dim u)
    (destructuring-bind (vr vc) (dim v)
      ;;; need a new matrix z to hold the values of the convolved matrix
      ;;; dim z should be dim u + dim v - 1
      (let ((zr (+ ur vr (- 1)))
	    (zc (+ uc vc (- 1))))
	(let ((z (make-instance (class-of u) :rows zr :cols zc))
	      (ustartr 0)
	      (uendr 0)
	      (vstartr (- vr 1))
	      (vendr 0)
	      (ustartc 0)
	      (uendc 0)
	      (vstartc (- vc 1))
	      (vendc 0)
	      (acc 0))
	  (dotimes (i zr)
	    (setf ustartr (max 0 (- i vr -1)))
	    (setf uendr (min (- ur 1) i))
	    (setf vstartr (- vr (max (- vr i) 1)))
	    (setf vendr (- vr (min (- zr i) vr)))
	    (dotimes (j zc)
	      (setf ustartc (max 0 (- j vc -1)))
	      (setf uendc (min (- uc 1) j))
	      (setf vstartc (- vc (max (- vc j) 1)))
	      (setf vendc (- vc (min (- zc j) vc)))
	      (setf acc 0)
		  (print (list i j ";" ustartr uendr ";" ustartc uendc
			       ";" vstartr vendr ";" vstartc vendc))
	      (do ((urow ustartr (1+ urow))
		   (vrow vstartr (1- vrow)))
		  ((> urow uendr))
		(do ((ucol ustartc (1+ ucol))
		     (vcol vstartc (1- vcol)))
		    ((> ucol uendc))
		  (incf acc (* (val u urow ucol) (val v vrow vcol)))))
	      (if truncate
		  (set-val z i j (fit z acc))
		(set-val z i j acc))))
	  z)))))


(defmethod old-discrete-convolve ((u matrix) (v matrix) &key (truncate))
  (declare (optimize (speed 3) (safety 0) (space 0)))
  ;;; ur, uc, vr, vc are the number of rows and columns in u and v
  (destructuring-bind (ur uc) (dim u)
    (destructuring-bind (vr vc) (dim v)
      ;;; need a new matrix z to hold the values of the convolved matrix
      ;;; dim z should be dim u + dim v - 1
      (let ((zr (+ ur vr (- 1)))
	    (zc (+ uc vc (- 1))))
	(let ((z (make-instance (class-of u) :rows zr :cols zc)))
	  (dotimes (i zr)
	    (let ((ustartr (max 0 (- i vr -1)))
		  (uendr (min (- ur 1) i))
		  (vstartr (- vr (max (- vr i) 1)))
;		  (vendr (- vr (min (- zr i) vr)))
		  )
	      (dotimes (j zc)
		(let ((ustartc (max 0 (- j vc -1)))
		      (uendc (min (- uc 1) j))
		      (vstartc (- vc (max (- vc j) 1)))
;		      (vendc (- vc (min (- zc j) vc))
		      (acc 0))
;		  (print (list i j ";" ustartr uendr ";" ustartc uendc
;			       ";" vstartr vendr ";" vstartc vendc))
		  (do ((urow ustartr (1+ urow))
		       (vrow vstartr (1- vrow)))
		    ((> urow uendr))
		    (do ((ucol ustartc (1+ ucol))
			 (vcol vstartc (1- vcol)))
			((> ucol uendc))
		      (let ((uval (val u urow ucol))
			    (vval (val v vrow vcol)))
			(incf acc (* uval vval)))))
		  (if truncate
		      (set-val z i j (fit z acc))
		    (set-val z i j acc))))))
	  z)))))

(defun gaussian-kernel (k sigma)
  (let* ((d (1+ (* 2 k)))
	 (a (make-instance 'double-float-matrix :rows d :cols d))
	 (q (* 2 sigma sigma))
	 (z (/ (* pi q))))
    (dotimes (i d)
      (dotimes (j d)
	(set-val a i j
		 (* (exp (- (/ (+ (* (- i k) (- i k))
				  (* (- j k) (- j k)))
			       q)))
		    z))))
    (scalar-divide a (sum-range a 0 (- d 1) 0 (- d 1)))
    a))


;;; NOTE!!! These subset-matrix calls are a bad thing.
;;; Copying these matrices is a big nono. Let's figure out a better
;;; way to do this...
(defun separable-discrete-convolve (m h &key (truncate nil))
  (let ((rowstart (floor (/ (1- (rows h)) 2)))
	(rowend (floor (/ (rows h) 2)))
	(colstart (floor (/ (1- (cols h)) 2)))
	(colend (floor (/ (cols h) 2))))
    (let ((h1 (subset-matrix h rowstart rowend 0 (1- (cols h))))
	  (h2 (subset-matrix h 0 (1- (rows h)) colstart colend)))
      (scalar-divide h1 (sum h1))
      (scalar-divide h2 (sum h2))
      (let* ((m1 (discrete-convolve m h1 :truncate truncate))
	     (m2 (discrete-convolve m1 h2 :truncate truncate)))
	m2))))

(defun separable-discrete-convolve-word (m h &key (truncate nil))
  (let ((rowstart (floor (/ (1- (rows h)) 2)))
	(rowend (floor (/ (rows h) 2)))
	(colstart (floor (/ (1- (cols h)) 2)))
	(colend (floor (/ (cols h) 2))))
    (let ((h1 (subset-matrix h rowstart rowend 0 (1- (cols h))))
	  (h2 (subset-matrix h 0 (1- (rows h)) colstart colend)))
      (scalar-divide h1 (sum h1))
      (scalar-divide h2 (sum h2))
      (print-matrix h1)
      (let* 
	  ((convfunc #'discrete-convolve)
	   (m1 (apply convfunc (list m h1 :truncate truncate)))
	   (m2 (apply convfunc (list m1 h2 :truncate truncate))))
	m2))))

(defun gaussian-blur (m &key (k 2) (sigma 1) (truncate nil))
  (let ((h (gaussian-kernel k sigma)))
    (separable-discrete-convolve m h :truncate truncate)))

(defun gaussian-blur-word (m &key (k 2) (sigma 1) (truncate t))
  (let ((h (copy-to-ub8-matrix
	    (scalar-mult
	     (gaussian-kernel k sigma) 255))))
    (print-range h 0 2 0 2)
    (separable-discrete-convolve-word m h :truncate truncate)))

(defun gaussian-blur-orig (m &key (k 2) (sigma 1) (truncate nil))
  (let* ((h (gaussian-kernel k sigma)))
    (discrete-convolve m h :truncate truncate)))

(defparameter *x-derivative-conv-matrix*
  (transpose (array->fixnum-matrix #2A((1 0 -1)(1 0 -1)(1 0 -1)))))

(defun x-derivative (m &key (truncate t))
  (discrete-convolve (copy-to-fixnum-matrix m)
		     *x-derivative-conv-matrix*
		     :truncate truncate :matrix-class 'fixnum-matrix))

(defparameter *y-derivative-conv-matrix*
  (array->fixnum-matrix #2A((1 0 -1)(1 0 -1)(1 0 -1))))

(defun y-derivative (m &key (truncate t))
  (discrete-convolve (copy-to-fixnum-matrix m) 
		     *y-derivative-conv-matrix*
		     :truncate truncate :matrix-class 'fixnum-matrix))
  
(defun gradmag (m &key (truncate nil))
  (let ((xd (x-derivative m :truncate truncate))
	(yd (y-derivative m :truncate truncate)))
    (mat-square! xd)
    (mat-square! yd)
    (mat-add xd yd)
    (mat-sqrt! xd)
    xd))

(defun variance-window (a &key (k 2))
  (destructuring-bind (m n) (dim a)
    (let ((zm (1- m))
	  (zn (1- n)))
      (map-matrix-copy a #'(lambda (m i j) (variance-range
					    m
					    (max 0 (- i k))
					    (min zm (+ i k))
					    (max 0 (- j k))
					    (min zn (+ j k))))
		       :matrix-class 'double-float-matrix))))

(defun sample-variance-window (a &key (k 1) (truncate nil))
  (destructuring-bind (m n) (dim a)
    (let ((zm (1- m))
	  (zn (1- n)))
      (map-matrix-copy a #'(lambda (m i j) (sample-variance-range
					    m
					    (max 0 (- i k))
					    (min zm (+ i k))
					    (max 0 (- j k))
					    (min zn (+ j k))))))))

(defmethod morphological-op ((u matrix) (v matrix) f)
  ;;; ur, uc, vr, vc are the number of rows and columns in u and v
  (destructuring-bind (ur uc) (dim u)
    (destructuring-bind (vr vc) (dim v)
      ;;; need a new matrix z to hold the values of the convolved matrix
      ;;; dim z should be dim u + dim v - 1
      (let ((zr (+ ur vr (- 1)))
	    (zc (+ uc vc (- 1))))
	(let ((z (make-instance (class-of u) :rows zr :cols zc)))
	  (dotimes (i zr)
	    (let ((ustartr (max 0 (- i vr -1)))
		  (uendr (min (- ur 1) i))
		  (vstartr (- vr (max (- vr i) 1)))
;		  (vendr (- vr (min (- zr i) vr)))
		  )
	      (dotimes (j zc)
		(let ((ustartc (max 0 (- j vc -1)))
		      (uendc (min (- uc 1) j))
		      (vstartc (- vc (max (- vc j) 1)))
		      (acc '()))
;		      (vendc (- vc (min (- zc j) vc))))
;		  (print (list i j ";" ustartr uendr ";" ustartc uendc
;			       ";" vstartr vendr ";" vstartc vendc))
		  (do ((urow ustartr (1+ urow))
		       (vrow vstartr (1- vrow)))
		      ((> urow uendr))
		    (do ((ucol ustartc (1+ ucol))
			 (vcol vstartc (1- vcol)))
			((> ucol uendc))
		      (setf acc (funcall f acc (val u urow ucol) (val v vrow vcol)))))
;		      (setf acc (max acc (* (val u urow ucol) (val v vrow vcol))))))
		  (set-val z i j acc)))))
	  z)))))

(defun separable-morphological-op (m h f)
  (let ((rowstart (floor (/ (1- (rows h)) 2)))
	(rowend (floor (/ (rows h) 2)))
	(colstart (floor (/ (1- (cols h)) 2)))
	(colend (floor (/ (cols h) 2))))
    
    (declare (dynamic-extent rowstart rowend colstart colend)
	     (index-type rowstart rowend colstart colend))
    
    (let ((h1 (subset-matrix h rowstart rowend 0 (1- (cols h))))
	  (h2 (subset-matrix h 0 (1- (rows h)) colstart colend)))
      (let* 
	  ((m1 (morphological-op m h1 f))
	   (m2 (morphological-op m1 h2 f)))
	m2))))

(defmethod dilate ((u matrix) (v matrix))
  (separable-morphological-op u v #'(lambda (acc uval vval)
				      (let ((opval (+ uval vval)))
					(cond
					 ((null acc) opval)
					 (t (max acc opval)))))))

(defmethod erode ((u matrix) (v matrix))
  (separable-morphological-op u v #'(lambda (acc uval vval)
				      (let ((opval (- uval vval)))
					(cond
					 ((null acc) opval)
					 (t (min acc opval)))))))

(defmethod dilate-orig ((u matrix) r)
  ;;; ur, uc, vr, vc are the number of rows and columns in u and v
  (destructuring-bind (ur uc) (dim u)
	(let ((z (make-instance (class-of u) :rows ur :cols uc)))
	  (dotimes (i ur)
	    (let ((ustartr (max 0 (- i r)))
		  (uendr (min (- ur 1) (+ i r))))
	      (dotimes (j uc)
		(let ((ustartc (max 0 (- j r)))
		      (uendc (min (- uc 1) (+ j r)))
		      (max-val (val u i j)))
		  (do ((urow ustartr (1+ urow)))
		      ((> urow uendr))
		    (do ((ucol ustartc (1+ ucol)))
			((> ucol uendc))
		      (setf max-val (max max-val (val u urow ucol)))))
		  (set-val z i j max-val)))))
	  z)))


(defmethod erode-orig ((u matrix) r)
  ;;; ur, uc, vr, vc are the number of rows and columns in u and v
  (destructuring-bind (ur uc) (dim u)
	(let ((z (make-instance (class-of u) :rows ur :cols uc)))
	  (dotimes (i ur)
	    (let ((ustartr (max 0 (- i r)))
		  (uendr (min (- ur 1) (+ i r))))
	      (dotimes (j uc)
		(let ((ustartc (max 0 (- j r)))
		      (uendc (min (- uc 1) (+ j r)))
		      (min-val (val u i j)))
		  (do ((urow ustartr (1+ urow)))
		      ((> urow uendr))
		    (do ((ucol ustartc (1+ ucol)))
			((> ucol uendc))
		      (setf min-val (min min-val (val u urow ucol)))))
		  (set-val z i j min-val)))))
	  z)))

(defmethod threshold ((u matrix) (tval number) &key (minval 0) (maxval 255))
  (map-set-val-copy u #'(lambda (x) (if (> x tval)
					maxval
				      minval))))

