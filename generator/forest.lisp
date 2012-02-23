(defpackage #:forest
  (:use #:common-lisp #:cl-user))

(in-package #:forest)

(defconstant +tile-size+ 64)

(defvar *editor* nil)

(defun editor (1st 2nd &rest rest)
  (let ((fn-name (format nil "exports.~A.func~A" 1st 2nd)))
    (apply #'format (cons *editor* (cons fn-name rest)))))

(defun square (x)
  (* x x))

(defun make-point (a b)
  (cons a b))

(defun get-x (point)
  (car point))

(defun get-y (point)
  (cdr point))

(defun add-point (a b)
  (make-point 
   (+ (get-x a) (get-x b))
   (+ (get-y a) (get-y b))))

(defun distance (a b)
  (sqrt (+ (square (- (get-x a) (get-x b)))
	   (square (- (get-y a) (get-y b))))))

(defun output-boulder (pos)
  (editor "Boulder" "({x=~A,y=~A},~A,~A)~%"
	  (get-x pos) (get-y pos) (crandom 6)
	  (+ 5.0 (* 0.001 (crandom 1000)))))

(defun offset-point (pos x y)
  (add-point pos (make-point x y)))

(let ((prev 0))
  (defun jitter ()
    (let ((val (- (crandom 6) 3)))
      (if (/= val prev)
	  (setf prev val)
	  (jitter)))))

(defun save-gravel (pos x y)
  (editor "Gravel" "({x=~A,y=~A})~%"
	  (+ x (get-x pos)) (+ y (get-y pos))))

(defun save-half-gravel (pos x y dir)
  (editor "ForestTile" "({x=~A,y=~A},'~A',~A)~%"
	  (+ x (get-x pos))
	  (+ y (get-y pos))
	  (if (> dir 0) #\h #\p)
	  3.0))

(defvar *next* nil)

(defmacro do-next-time (&body body)
  `(setf *next* (lambda () ,@body)))

(let ((prev 'side))
  (defun find-new-boulder-pos (pos dir)
    (funcall *next*)
    (let ((dice (crandom 6)))
      (cond 
	((not (eq prev 'vertical))
	 (setf prev 'vertical)
	 (do-next-time
	   (output-boulder (offset-point pos (jitter) (* dir 32))))
	 (offset-point pos 0 (* dir 64)))
	((>= dice 2)
	 (setf prev 'slope)
	 (do-next-time
	   (output-boulder (offset-point pos 24 (* dir (+ 24 (jitter)))))
	   (output-boulder (offset-point pos 48 (* dir (+ 48 (jitter)))))
	   (save-half-gravel pos 32 (if (> dir 0) 24 -40) dir)
	   (save-gravel pos 32 (if (> dir 0) -40 -104)))
	 (offset-point pos 64 (* dir 64)))
	(t
	 (setf prev 'horizontal)
	 (do-next-time
	   (output-boulder (offset-point pos 32 0))
	   (save-gravel pos 32 -40))
	 (offset-point pos 64 0))))))

(defun save-single-boulder (pos dir)
  (output-boulder pos)
  (find-new-boulder-pos pos dir))

(defun get-boulder-length (pos)
  (floor (* 700.0 (noise3D 0.0 (+ 0.5 (floor (get-x pos))) 0.0))))

(defun save-last-boulder (pos dir)
  pos)

(defun is-critical-altitude? (pos dir)
  (or (and (> dir 0) (> (get-y pos) 1024))
      (and (< dir 0) (< (get-y pos) -256))))

(defun save-boulders (pos len dir)
  (let* ((new-pos (save-single-boulder pos dir))
	 (new-len (- len (distance pos new-pos))))
    (if (or (< new-len 0.0) (is-critical-altitude? pos dir))
	(save-last-boulder pos dir)
	(save-boulders new-pos new-len dir))))

(defun get-grass-length (pos)
  (floor (* 10.0 (noise3D (+ 0.5 (floor (get-x pos))) 0.0 0.0))))

(defun forest-tile (id pos depth)
  (editor "Gravel" "({x=~A,y=~A})~%" (get-x pos) (- (get-y pos) 64))
  (editor "GrassTop" "({x=~A,y=~A},'~A',~A)~%" 
	  (get-x pos) (get-y pos) id depth)
  (offset-point pos +tile-size+ 0.0))

(defun grass-tile (id-list pos)
  (if (null id-list)
      pos
      (grass-tile (rest id-list) (forest-tile (first id-list) pos 4.5))))

(defun put-grass (pos length)
  (cond ((= length 1) (grass-tile '(#\q) pos))
	((= length 2) (grass-tile '(#\i #\j) pos))
	((= length 4) (grass-tile '(#\a #\b #\c #\d) pos))
	(t (error "bad grass length"))))

(defun choose-grass-length (length)
  (cond ((>= length 4) (random-elt '(1 2 4)))
	((>= length 2) (random-elt '(1 2)))
	(t 1)))

(defun save-grass (pos length)
  (if (= length 0)
      pos
      (let ((piece (choose-grass-length length)))
	(save-grass (put-grass pos piece) (- length piece)))))

(defun determine-direction (pos)
  (cond ((<= (get-y pos) 0.0) 1.0)
	((>= (get-y pos) 300.0) -1.0) ; max height
	(t (- (* 2 (crandom 2)) 1))))

(defparameter *boulder-offset* 24)

(defun save-boulder-pile (pos &optional len direction)
  (let* ((*next* (lambda () nil))
	 (dir (or direction (determine-direction pos)))
	 (fixed-pos (offset-point pos -32 (- *boulder-offset*)))
	 (slope-length (or len (get-boulder-length pos)))
	 (new-pos (save-boulders fixed-pos slope-length dir)))
    (offset-point new-pos 32 *boulder-offset*)))

(defun get-tree-offset (x)
  (+ 50.0 (floor (* 75.0 (noise3D 0.0 0.0 (+ 0.5 (floor x)))))))

(defun save-tree (x y num z c)
  (editor "Tree" "({x=~A,y=~A},~A,~A,~A)~%" x y num z c))

(defun save-row-of-trees (x1 x2 y &optional (front? t))
  (if (> x1 x2)    
      (not front?)
      (let ((side (if (not front?) -2.0 1.0)))
	(save-tree x1 (- y (crandom 50)) (+ 3 (crandom 2))
		   (+ side (/ (crandom 1000) 1000.0))
		   (if front? 1.0 0.5))
	(save-row-of-trees (+ x1 (get-tree-offset x1)) x2 y (not front?)))))

(defun save-small-tree (x y front?)
  (save-tree x (- y (crandom 30)) (1+ (crandom 2))
	     (if front? 1 -1) (if front? 1 .5)))

(defun save-grass-with-shape (pos length)
  (let* ((new-pos (save-grass pos length))
 	 (x1 (get-x pos))
 	 (y1 (get-y pos))
 	 (x2 (get-x new-pos))
 	 (y2 (get-y new-pos))
	 (tree-x1 (+ x1 32 (get-tree-offset x1)))
	 (tree-x2 (- x2 (get-tree-offset x2))))
    (editor "Blocker" "({l=~A,t=~A,r=~A,b=~A})~%" x1 y1 x2 (- y2 16))
    (save-small-tree (+ x1 32) y1 nil)
    (let ((front? (save-row-of-trees tree-x1 tree-x2 y1)))
      (save-small-tree (- x2 32) y1 (not front?)))
    new-pos))

(defun save-land (pos len)
  (let ((new-pos (save-boulder-pile pos)))
    (setf new-pos (save-grass-with-shape new-pos (get-grass-length new-pos)))
    (let ((new-len (- len (distance pos new-pos))))
      (if (> new-len 0)
	  (save-land new-pos new-len)
	  new-pos))))

(defun save-forest ()
  (noise3D 0.0 0.0 0.0) ; first call to noise3D calls srandom
  (cseed 1) 
  (let ((name "forest-procedural.lua")
	(edit "Forest-edit.lua"))
    (with-open-file (*editor* edit :direction :output :if-exists :supersede)
    (with-open-file (*stream* name :direction :output :if-exists :supersede)
      (let ((pos (save-boulder-pile (make-point -10500.0 512.0) 600.0 -1)))
	(setf pos (save-grass-with-shape pos 4))
	(setf pos (save-land pos 15000.0))
	(setf pos (save-boulder-pile pos 1280.0 -1))
	(editor "LandingZone" "({x=~A,y=~A})~%" (get-x pos) (get-y pos))
	(setf pos (offset-point pos 1536 0))
 	(setf pos (save-land pos 15000.0))
	(editor "MineEntrance" "({x=~A,y=~A})~%" (get-x pos) (get-y pos)))
      (values)))))
