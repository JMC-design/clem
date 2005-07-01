
(in-package :clem-test)

(defun matrix-test-1 ()
  (let ((m (array->matrix #2A((1 2 3)(4 1 6)(7 1 9)))))
    (print-matrix (invert-matrix m)))
  t)

(defun matrix-test-2 ()
  (let ((m (array->matrix #2A((1 2 3)(4 5 6)(7 8 9)))))
    (print-matrix m)
    (swap-rows m 0 2)
    (swap-cols m 0 2)
    (print-matrix m)
    (let ((q (val m 0 0)))
      (map-row m 0 #'(lambda (x) (/ x q)))
      (scalar-mult-col m 0 4)
      (scalar-divide-col m 0 3)
      )
    (print-matrix m)
    )
  t)

(defun matrix-test-3 ()
  (let ((m1 (array->matrix #2A((1 2 3)(4 5 6)(7 8 9) (10 11 12)))))
    (print-matrix m1)
    (print (dim m1))
    
    (let ((t1 (transpose m1)))
      (print-matrix t1)
      (print (dim t1)))
    
    (let ((m2 (array->matrix #2A((1 2 3 4 5 6 7 8 9)))))
      (print m2)
      (print-matrix m2)
      (print (dim m2))
      ))
  t)

(defun matrix-test-4 ()
  (let ((m3 (array->matrix #2A((1) (2) (3) (4) (5) (6) (7) (8) (9)))))
    (print-matrix m3)
    (print (dim m3)))
  t)

(defun matrix-test-5 ()
  (let ((m (array->matrix #2A((1 2 3)(4 5 6)(7 8 9)))))
    (print-matrix (mat-mult m m))
    (let ((inv (invert-matrix m)))
      (if inv (print-matrix (invert-matrix m)))
      ))
  t)

(defun matrix-test-6 ()
  (let ((m (array->matrix #2A((1 2 3)(4 5 6)(7 8 9)))))
    (print-matrix (mat-mult m m))
    (let ((inv (invert-matrix m)))
      (if inv (print-matrix (invert-matrix m)))
      ))
  t)

(defun matrix-test-7 ()
  (let ((m (array->sb8-matrix #2A((1 2 3)(4 5 6)(7 2 8)))))
    (print-matrix m)
    (print-matrix (mat-mult m m))
    (let ((inv (invert-matrix m)))
      (if inv (print-matrix inv))
      ))
  t)

(defparameter m1 (make-instance 'double-float-matrix :rows 1000 :cols 1000))

(defun matrix-test-8 ()
  (dotimes (i 1000)
    (dotimes (j 1000)
      (set-val m1 i j (- i j)))))

(defmethod clem::mat-add ((a double-float-matrix) (b double-float-matrix))
  (declare (optimize (speed 3) (safety 0) (space 0)))
  (and (equal (dim a) (dim b))
       (destructuring-bind (m n) (dim a)
	 (declare (fixnum m n))
	 (let* ((c (clem::mat-copy-proto a))
		(v (clem::matrix-vals c))
		(va (clem::matrix-vals a))
		(vb (clem::matrix-vals b)))
	   (declare (type (simple-array double-float (* *)) v va vb))
	   (dotimes (i m c)
	     (dotimes (j n)
	       (setf (aref v i j)
		     (+
		      (aref va i j)
		      (aref vb i j)))))))))


(defun run-tests ()
  (let ((run (chutil:make-test-run)))
    (chutil:run-test #'matrix-test-1 "matrix-test-1" run)
    (chutil:run-test #'matrix-test-2 "matrix-test-2" run)
    (chutil:run-test #'matrix-test-3 "matrix-test-3" run)
    (chutil:run-test #'matrix-test-4 "matrix-test-4" run)
    (chutil:run-test #'matrix-test-5 "matrix-test-5" run)
    (chutil:run-test #'matrix-test-6 "matrix-test-6" run)
    (chutil:run-test #'matrix-test-7 "matrix-test-7" run)
    (format t "~&~A of ~A tests passed" (chutil:test-run-passed run) (chutil:test-run-tests run))
    ))


