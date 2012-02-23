(defpackage #:waterfall
  (:use #:common-lisp #:cl-user))

(in-package #:waterfall)

(defconstant +tile-size+ 64)

(defparameter *cave-height* 4)
(defparameter *cliff-tiles* 32)
(defparameter *entrance-width* 3)
(defparameter *cliff-width* (* *cliff-tiles* +tile-size+))
(defparameter *bridge-length* (* 8 +tile-size+))
(defparameter *elevator-height* (* 19 +tile-size+))
(defparameter *segment-length* (+ *bridge-length* *cliff-width*))

(defparameter *flat*
  (make-tile :id '(#\b #\c #\d) :offset 64 :elevation   0))

(defparameter *tiles1* 
  (list
   (make-tile :id '(#\P #\Z #\9) :offset  0 :elevation  64)
   (make-tile :id '(#\D #\M #\W) :offset 64 :elevation -64)
   (make-tile :id '(#\Q #\1 #\0) :offset 64 :elevation -32)
   (make-tile :id '(#\L #\U #\5) :offset  0 :elevation  32)
   *flat*))

(defparameter *tiles2* 
  (list
   (make-tile :id '(#\R #\2 #\!) :offset 32  :elevation 32)
   (make-tile :id '(#\z #\A #\B) :offset 32 :elevation   0)
   (make-tile :id '(#\n #\w #\F) :offset 32 :elevation -32)))

(defparameter *flat-top*
  (make-tile :id '(#\H #\I #\J) :offset  0 :elevation   0))

(defparameter *tiles3* 
  (list
   (make-tile :id '(#\O #\Y #\8) :offset  0 :elevation  64)
   (make-tile :id '(#\v #\E #\N) :offset 64 :elevation -64)
   (make-tile :id '(#\f #\h #\x) :offset 64 :elevation -32)
   (make-tile :id '(#\S #\3 #\@) :offset  0 :elevation  32)
   *flat-top*))

(defparameter *tiles4* 
  (list
   (make-tile :id '(#\g #\o #\p) :offset 32  :elevation 32)
   (make-tile :id '(#\j #\k #\l) :offset 32 :elevation   0)
   (make-tile :id '(#\T #\4 #\#) :offset 32 :elevation -32)))

(defparameter *x* (+ (* -3 *segment-length*) *bridge-length* 1024))
(defparameter *y* (- (- *elevator-height*) +tile-size+))

(defvar *floor-y* nil)
(defvar *floor-idx* nil)
(defvar *floor-offset* nil)

(defvar *ceiling-y* nil)
(defvar *ceiling-idx* nil)
(defvar *ceiling-offset* nil)

(defun get-height ()  
  (+ *cave-height* (- *floor-idx*) *ceiling-idx*))

(defun simple-column (x y t1 t2 h)
  (output "SimpleColumn(~A,~A,'~A','~A',~A)~%" x y t1 t2 h))

(defun save-entrance (side)
  (output "~AEntry(~A,~A,~A)~%" side *x* (+ *y* *floor-y*) (get-height))
  (incf *x* (* *entrance-width* +tile-size+)))

(defun choose-tileset (y tileset1 tileset2)
  (if (= 0 (nth-value 1 (floor y +tile-size+)))
      tileset1
      tileset2))

(defun update-floor-offset (x)
  (setf *floor-offset* x))

(defun update-ceiling-offset (x)
  (setf *ceiling-offset* x))

(defun index-update (offset)
  (cond ((> offset +tile-size+) 1)
	((< offset 0) -1)
	(t 0)))

(defun tile-difference (tile)
  (+ (tile-offset tile) (tile-elevation tile)))

(defun adjust-ceiling (tile)
  (let ((offset (+ *ceiling-offset* (tile-elevation tile))))
    (setf *ceiling-offset* (tile-difference tile))
    (incf *ceiling-idx* (index-update offset))
    (when (and (= 64 offset) (eq tile *flat-top*))
      (incf *ceiling-idx*))))

(defun adjust-floor (tile)
  (let ((offset (+ *floor-offset* (tile-elevation tile))))
    (setf *floor-offset* (tile-difference tile))
    (incf *floor-idx* (index-update offset))
    (when (and (= 0 offset) (eq tile *flat*))
      (decf *floor-idx*))))

(defparameter +floor-offset+ -12)

(defun save-cave-floor-shape (old-y)
  (let ((h (+ *y* (* 2 +tile-size+))))
    (save-line 
     (cons *x* (+ +floor-offset+ old-y h))
     (cons (+ *x* +tile-size+) (+ +floor-offset+ *floor-y* h)))))

(defun get-cave-ceiling-type (y1 y2)
  (cond ((> y1 y2) "\"CeilingLeftSlope\"")
	((< y1 y2) "\"CeilingRightSlope\"")
	(t "\"Box\"")))

(defun save-cave-ceiling-shape (old-y)
  (let* ((y (+ *y* (* *cave-height* +tile-size+)))
	 (y1 (+ y old-y +tile-size+))
	 (y2 (+ y *ceiling-y* +tile-size+)))
    (save-line (cons *x* y1) 
	       (cons (+ *x* +tile-size+) y2)
	       (get-cave-ceiling-type y1 y2))))

(defun get-candidate (noise-fn y tileset1 tileset2)
  (pick-candidate 
   (- (funcall noise-fn) y)
   (choose-tileset y tileset1 tileset2)))

(defvar *noise-var* 0.0)

(defun get-noise (y)
  (let ((x (sfloat (* 0.005 *x*))))
    (min 1.0 (* 1.5 (noise3D x (sfloat y) *noise-var*)))))

(defun floor-noise ()
  (* 8.0 +tile-size+ (- (expt (get-noise 0.0) 4.0) 0.5)))

(defun ceiling-noise ()
  (* 4.0 +tile-size+ (- 0.5 (expt (get-noise *cave-height*) 4.0))))

(defun get-floor-candidate ()
  (get-candidate #'floor-noise *floor-y* *tiles1* *tiles2*))

(defun get-ceiling-candidate ()
  (get-candidate #'ceiling-noise *ceiling-y* *tiles3* *tiles4*))

(defun put-spikes (x)
  (output "PutSpike(~A,~A)~%" x (+ *y* *floor-y* (* 2 +tile-size+) -16)))

(defvar *elevation* nil)
(defvar *descent* nil)

(defun is-crack ()
  (and (>= (length *elevation*) 2)
       (> (first *elevation*) 0)
       (< (second *elevation*) 0)
       (* 0.5 +tile-size+)))

(defun is-pit ()
  (and (>= (length *elevation*) 3)
       (> (first *elevation*) 0)
       (= (second *elevation*) 0)
       (< (third *elevation*) 0)
       +tile-size+))

(defun decide-whether-to-put-spikes (candidate)
  (push (tile-elevation candidate) *elevation*)
  (let ((offset (or (is-crack) (is-pit))))
    (when (and offset (> (get-height) 4))
      (put-spikes (- *x* offset)))))

(defun is-ceiling-crack ()
  (and (>= (length *descent*) 2)
       (< (first *descent*) 0)
       (> (second *descent*) 0)))

(defun is-ceiling-pit ()
  (and (>= (length *descent*) 3)
       (< (first *descent*) 0)
       (= (second *descent*) 0)
       (> (third *descent*) 0)))

(defun put-stalactite (x-offset y-offset)
  (when (> (get-height) 4)
    (output "PutStalactite(~A,~A)~%"
	    (- *x* x-offset)
	    (+ *y* *ceiling-y* (* 3 +tile-size+) y-offset))))

(defun decide-whether-to-put-stalactite (candidate)
  (push (tile-elevation candidate) *descent*)
  (cond ((is-ceiling-crack) (put-stalactite (* 0.5 +tile-size+) -4))
	((is-ceiling-pit) (put-stalactite +tile-size+ 8))))

(defun pick-simple-column ()
  (let* ((old-floor-y *floor-y*)
	 (old-ceiling-y *ceiling-y*)
	 (floor-candidate (get-floor-candidate))
	 (ceiling-candidate (get-ceiling-candidate)))
    (decide-whether-to-put-spikes floor-candidate)
    (decide-whether-to-put-stalactite ceiling-candidate)
    (incf *floor-y* (tile-elevation floor-candidate))
    (incf *ceiling-y* (tile-elevation ceiling-candidate))
    (save-cave-ceiling-shape old-ceiling-y)
    (save-cave-floor-shape old-floor-y)
    (adjust-ceiling ceiling-candidate)
    (adjust-floor floor-candidate)
    (simple-column *x* (+ *y* (* +tile-size+ *floor-idx*))
		   (random-elt (tile-id floor-candidate))
		   (random-elt (tile-id ceiling-candidate))
		   (get-height))))

(defun save-tile (tile-id x y &optional (depth 1))
  (output "WaterfallTile('~C',~A,~A,~A)~%" tile-id x y depth))

(defun save-procedural-internode ()
  (let ((*floor-y* 0)
	(*floor-idx* 0)
	(*floor-offset* +tile-size+)

	(*ceiling-y* 0)
	(*ceiling-idx* 0)
	(*ceiling-offset* 0)

	(*descent* nil) ; elevation for ceiling
	(*elevation* nil))

    (save-entrance "Left")
    (dotimes (i (- *cliff-tiles* (* 2 *entrance-width*)))
      (pick-simple-column)
      (incf *x* +tile-size+))
    (adjust-floor *flat*)
    (adjust-ceiling *flat-top*)
    (save-entrance "Right")
    (incf *y* *floor-y*)))

(defun save-rock-column (tileset x y count)
  (dotimes (i count)
    (save-tile (random-elt tileset) x (+ y (* i +tile-size+)))))

(defun save-cliff-top-line (x y cliff-end)
  (let ((y2 (+ y +tile-size+)))
    (save-generic-line 
     (cons (+ x +tile-size+) y2)
     (cons (+ x cliff-end) y2))))

(defun choose-plant-type ()
  (if (= 0 (crandom 5)) #\b #\a))

(defun save-plant-obj (x y)
  (output "RockPlant(~A,~A,~A,'~C')~%" 
	  x (- y 10 (crandom 10)) (- (crandom 2) 0.5) (choose-plant-type)))

(defun save-plant-row (x y amount)
  (when (> amount 0)
    (let ((q (+ 4 (crandom 4))))
      (save-plant-obj x y)
      (save-plant-row (+ x q) y (- amount q)))))

(defun save-cliff-top (x y)
  (let ((bottom (- y (* 4 +tile-size+)))
	(cliff-end (- *cliff-width* +tile-size+)))
    (save-tile #\a x y)
    (save-tile #\e (+ x cliff-end) y)
    (save-cliff-top-line x y cliff-end)
    (save-rock-column '(#\i #\q #\y) x bottom 4)
    (save-rock-column '(#\m #\u #\C) (+ x cliff-end) bottom 4)
    (loop for i from +tile-size+ to (- cliff-end 0.001)  by +tile-size+
       do (save-tile (random-elt '(#\b #\c #\d)) (+ x i) y)
       do (save-rock-column '(#\s #\t) (+ x i) bottom 4))
    (save-plant-row (+ x +tile-size+) (+ y +tile-size+)
		    (- cliff-end (* 2 +tile-size+)))))

(defun save-bamboo-bridge (x y)
  (output "BambooBridge(~A,~A)~%" x y))

(defun elevator-block (x y flip)
  (output "ElevatorBlock(~A,~A,~A)~%" x y flip))

(defun first-elevator-x ()
  (+ (* -3 *segment-length*) (* 15 +tile-size+)))

(defun save-waterfall ()
  (noise3D 0.0 0.0 0.0) ; first call to noise3D calls srandom
  (cseed 1) 
  (let ((name "waterfall-procedural.lua")
	x-backup y-backup)
    (with-open-file (*stream* name :direction :output :if-exists :supersede)
      (let ((offset -1024))
	(dotimes (i 3)
	  (save-cliff-top offset -128)
	  (save-bamboo-bridge (- offset *bridge-length* +tile-size+) -128)
	  (decf offset *segment-length*)))
      (elevator-block (first-elevator-x) -128 "false")
      (setf x-backup *x*)
      (save-procedural-internode)
      (save-bamboo-bridge (- *x* +tile-size+) (+ *y* +tile-size+))
      (incf *x* *bridge-length*)
      (save-procedural-internode)
      (save-bamboo-bridge (- *x* +tile-size+) (+ *y* +tile-size+))
      (incf *x* *bridge-length*)
      (elevator-block *x* (+ *y* +tile-size+) "true")

      (let ((*noise-var* 2.0))     
	(decf *y* *elevator-height*)
	(incf *y* (* 5 +tile-size+)) ; hacky adjustment
	(setf y-backup *y*)
	(setf *x* x-backup)
	(decf *x* *bridge-length*)
	(elevator-block (- *x* +tile-size+) (+ *y* +tile-size+) "false")
	(save-bamboo-bridge (- *x* +tile-size+) (+ *y* +tile-size+))
	(incf *x* *bridge-length*)
	(save-procedural-internode)
	(save-bamboo-bridge (- *x* +tile-size+) (+ *y* +tile-size+))
	(incf *x* *bridge-length*)
	(save-procedural-internode))

      (let ((*noise-var* 4.0))
	(setf *x* x-backup)
	(setf *y* y-backup)
	(decf *y* *elevator-height*)
	(incf *y* (* 2 +tile-size+))
	(save-procedural-internode)
	(save-bamboo-bridge (- *x* +tile-size+) (+ *y* +tile-size+))
	(incf *x* *bridge-length*)
	(save-procedural-internode)
	(save-bamboo-bridge (- *x* +tile-size+) (+ *y* +tile-size+))
	(incf *x* *bridge-length*))
      
      (output "CaveExit(~A,~A)~%" *x* *y*)

      (values))))
