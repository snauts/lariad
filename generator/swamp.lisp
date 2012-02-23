(export '*stream*)
(defvar *stream* nil)

(defstruct tile id offset elevation)
(export 'make-tile)
(export 'tile-id)
(export 'tile-offset)
(export 'tile-elevation)

(defparameter *tiles* 
  (list
   (make-tile :id #\a :offset  0 :elevation  64)
   (make-tile :id #\b :offset  0 :elevation  32)
   (make-tile :id #\c :offset 32 :elevation   0)
   (make-tile :id #\d :offset 32 :elevation -32)
   (make-tile :id #\e :offset 64 :elevation -64)))

(export 'output)
(defun output (&rest rest)
  (apply #'format (cons *stream* rest)))

(defun save-tile (tile-id x y &optional (depth 1))
  (output "SwampTile('~C',~A,~A,~A)~%" tile-id x y depth))

(defvar *height* 0.0)
(defvar *elevation* 0.0)
(defvar *water-map* nil)
(defvar *height-map* nil)
(defvar *surface-map* nil)

(defconstant +tile-size+ 64)
(defconstant +half-tile-size+ (/ +tile-size+ 2))

(defparameter *fadeout-height* (* -3 +tile-size+))

(defparameter *length* 21000)
(defparameter *end-flats* 1200)
(defparameter *flats* 200)

(defun swamp-noise-fn (x)
  (+ (* 1.20 (expt (noise3D x 0.0 0.0) 2.0))
     (* 0.45 (noise3D (* 2.0 x) 0.0 0.0))))

(defun not-flats (x)
  (< *flats* x (- *length* *end-flats*)))

(defun swamp-noise (x0 x1)
  (if (not-flats x0)
      (max 0.4 (swamp-noise-fn x1))
      0.5))

(defun get-displacement (x)
  (* 200.0 (+ -1.0 (* 2.0 (swamp-noise x (* 0.003 (sfloat x)))))))

(defun compare (diff)
  (lambda (x) (abs (- (tile-elevation x) diff))))

(export 'pick-candidate)
(defun pick-candidate (diff &optional (tiles *tiles*))
  (first (sort (copy-list tiles) #'< :key (compare diff))))

(defun save-rectangle (group left right bottom top)
  (output "eapi.NewShape(staticBody,nil,{l=~A,r=~A,b=~A,t=~A},'~A')~%" left
    right bottom top group))

(defun save-position (position &optional (with-comma t))
  (output (if with-comma "{~A,~A}," "{~A,~A}") (car position) (cdr position)))

(export 'save-generic-line)
(defun save-generic-line (start end  &optional (type nil))
  (output "shape.Line(")
  (save-position start)
  (save-position end type)
  (when type 
    (output "~A" type))
  (output ")~%"))
  
(export 'save-line)
(defun save-line (start end &optional (type nil))
  (save-generic-line start end type))
  
(defun save-line-tile (candidate x height)
  (let* ((delta (tile-elevation candidate))
	 (offset (tile-offset candidate)))
    (save-tile (tile-id candidate) x height)
    (if (= delta 0)
      (save-rectangle "Box" x (+ x +tile-size+) (- (+ height offset) 5) (+ height offset))
      (if (< delta 0)
        (save-rectangle "RightSlope" x (+ x +tile-size+) (+ height offset delta) (+ height offset))
        (save-rectangle "LeftSlope" x (+ x +tile-size+) (+ height offset) (+ height offset delta))
      )
    )
))

(defun save-column (candidate x y)
  (push (cons x *elevation*) *height-map*)
  (push (lambda () (save-line-tile candidate x y)) *surface-map*)
  (save-tile #\i x *fadeout-height*)
  (when (= (mod y +tile-size+) +half-tile-size+)
    (save-tile #\c x (- y +half-tile-size+)))
  (loop for y from (+ *fadeout-height* +tile-size+)
              to (- y +tile-size+)
              by +tile-size+
     do (save-tile (if (= 0 (random 2)) #\j #\x) x y)))

(defun save-ground (x)
  (setf *height* (get-displacement x))
  (let* ((diff (- *height* *elevation*))
	 (candidate (pick-candidate diff))
	 (y (- *elevation* (tile-offset candidate))))
    (save-column candidate x y)
    (incf *elevation* (tile-elevation candidate))))

(export 'align-to-tile)
(defun align-to-tile (x)
  (let ((val (* (floor x +tile-size+) +tile-size+)))
    (if (>= val x) val (+ val +tile-size+))))

(defun save-terrain ()
  (let ((*height* 0.0)
	(*elevation* 0.0))
    (loop for x from 0 to *length* by +tile-size+ do (save-ground x))
    (push (cons (align-to-tile *length*) *elevation*) *height-map*)))

(defun iterate-height-map (fn)
  (let* ((height-map *height-map*)
	 (prev (pop height-map)))
    (loop while height-map
       do (let ((this (pop height-map)))	    
	    (funcall fn prev this)
	    (setf prev this)))))

(defun interpolate (p1 p2 x)
  (let ((x1 (car p1))
	(y1 (cdr p1))
	(x2 (car p2))
	(y2 (cdr p2)))
    (+ y1 (* (- y2 y1) (/ (- x x1) (- x2 x1))))))

(defun get-height (x)
  (iterate-height-map
   (lambda (p2 p1)
     (when (<= (car p1) x (car p2))
       (return-from get-height (interpolate p1 p2 x))))))

(defun moss-noise (x w1 w2)
  (+ -1.0 (* 2.0 (noise3D (* 0.1 x w1) (* 0.1 x w2) 0.0))))

(defun moss-displacement (x w1 w2)
  (- (* +half-tile-size+ (moss-noise x w1 w2)) +half-tile-size+))

(defun is-water (x)
  (dolist (i *water-map* nil)
    (when (<= i x (+ +tile-size+ i))
      (return-from is-water t))))

(defparameter *moss-tile* #\f)

(defparameter *min-plant-spacing* 2)

(defun save-plant-tiles (xx yy depth type)
  (save-tile (car type) xx (+ yy +tile-size+) depth)
  (save-tile (cdr type) xx yy depth)
  *min-plant-spacing*)

(defun choose-plant (y)
  (if (> y (* 0.2 +tile-size+))
      (cons #\g #\o)
      (cons #\h #\p)))

(defun save-plant (x y bucket)
  (let ((xx (+ x (moss-displacement (+ 1000000.0 x) 1 0)))
	(yy (+ y (moss-displacement (+ 1000000.0 x) 0 1))))
    (if (and (= 0 (crandom 3)) (> 0 bucket) (not-near-pine xx) (not-flats x))
	(save-plant-tiles xx yy (1- (* 2 (crandom 2))) (choose-plant y))
	(decf bucket))))

(defvar *pines* nil)

(defun not-near-pine (x)
  (dolist (i *pines* t)
    (when (< (abs (- i x)) +tile-size+)
      (return-from not-near-pine nil))))

(defun save-moss-ball (x y)
  (let ((xx (+ x (moss-displacement x 1 0)))
	(yy (+ y (moss-displacement x 0 1))))
    (save-tile *moss-tile* xx yy (+ 3 (crandom 3)))))

(defun save-frog (x y)
  (output "SwampFrog(~A,~A,~A)~%" x y (+ -1 (* 2 (crandom 2)))))

(defun save-insect (x y)
  (output "SwampInsect(~A,~A,~A,~A)~%" 
	  x y (- 3 (crandom 7)) (+ 24 (crandom 8))))

(defun maybe-save-frog (x y)
  (when (and (= 0 (crandom 20)) (not-flats x))
    (save-frog x y)))

(defun maybe-save-insect (x y)
  (when (and (= 0 (crandom 20)) (not-flats x))
    (save-insect x (+ y +half-tile-size+ (crandom +tile-size+)))))

(defun save-misc ()
  (let ((bucket *min-plant-spacing*))
    (loop
       for x from +half-tile-size+ to *length* by (/ +half-tile-size+ 2)
       for y = (get-height x)
       do (when (not (is-water x))
	    (setf bucket (save-plant x y bucket))	    
	    (maybe-save-insect x y)
	    (maybe-save-frog x y)
	    (save-moss-ball x y)))))

(defun save-water-tile (id pos)
  (push (- (car pos) +tile-size+) *water-map*)
  (save-tile id (- (car pos) +tile-size+) (- (cdr pos) +tile-size+) 2))

(defun sub-point (p1 p2)
  (cons (- (car p1) (car p2)) (- (cdr p1) (cdr p2))))

(defun save-pond-shape (pp1 pp2)
  (let ((p1 (sub-point pp1 (cons +tile-size+ +half-tile-size+)))
	(p2 (sub-point pp2 (cons 0 +half-tile-size+))))
    (save-rectangle "Box" (- (car p1) 5) (+ (car p1) 2)
      (cdr p1) (+ (cdr p1) +half-tile-size+))
    (save-rectangle "Box" (- (car p2) 2) (+ (car p2) 5)
      (cdr p2) (+ (cdr p2) +half-tile-size+))
    (save-rectangle "PondBottom" (car p1) (car p2) (- (cdr p1) 5) (cdr p1))))

(defun save-stump (pond pos)
  (let ((x (+ (car pos) (* +tile-size+ (* 0.5 (- (length pond) 3))))))
    (save-rectangle "OneWayGround" x (+ x +tile-size+) (- (cdr pos) 5) (cdr pos))
    (save-tile #\v x (- (cdr pos) +half-tile-size+) 1.9)))

(defun save-long-pond (pond)
  (let ((pos (first pond)))
    (when (> (length pond) 3)
      (save-stump pond pos))
    (save-water-tile #\k (pop pond))  
    (loop while (> (length pond) 1)
       do (save-water-tile #\l (pop pond)))
    (save-pond-shape pos (first pond))
    (save-water-tile #\m (pop pond))))

(defun save-short-pond (pond)
  (save-pond-shape (first pond) (first pond))
  (save-water-tile #\n (pop pond)))

(defun save-pond (pond)
  (if (= 1 (length pond))
      (save-short-pond pond)
      (save-long-pond pond)))

(defun is-pond-candidate (h1 h2 water)
  (and h1 h2 water
       (> h1 (cdr (first water)))
       (> h2 (cdr (first water)))))

(defun save-water ()
  (let (ground water height)
    (labels ((flat-ground (peat p1)
	       (push peat ground)
	       (push p1 water))
	     (rugged-ground (peat p1 p2)
	       (choose-between-ground-and-water p2)
	       (setf ground nil water nil)
	       (setf height (cdr p1))
	       (funcall peat))
	     (choose-between-ground-and-water (p2)
	       (when water
		 (if (not (is-pond-candidate height (cdr p2) water))
		     (mapc #'funcall ground)
		     (save-pond water)))))
      (iterate-height-map
       (lambda (p1 p2)
	 (let ((peat (pop *surface-map*)))
	   (if (= (cdr p1) (cdr p2))
	       (flat-ground peat p1)
	       (rugged-ground peat p1 p2)))))
      (mapc #'funcall ground))))

(defparameter *pine-size* 256)
(defparameter *half-pine-size* (/ *pine-size* 2))

(defun save-pine (x y)
  (when (not-flats x)
    (output "PutPine('~A',{~A, ~A},~A)~%" 
	    (1+ (crandom 4)) x y (1- (* 2 (crandom 2))))))

(defun maybe-save-pine (p1 p2)
  (let ((x (caar p2))
	(y (cdar p2))
	(end1 (cdr p1))
	(end2 (cdr p2))
	(middle (car p1))
	(range (- (caar p1) (caar p2))))
    (when (or (< (cdr end1) (cdr middle))
	      (< (cdr end2) (cdr middle)))
      (let ((pine-x (+ x (crandom range))))
	(save-pine (- pine-x *half-pine-size*) y)
	(push pine-x *pines*)))))
  
(defun save-pines ()
  (let (start last)
    (iterate-height-map
     (lambda (p1 p2)
       (if (= (cdr p1) (cdr p2))
	   (when (and last (null start))
	     (setf start (cons p1 last)))
	   (when start
	     (maybe-save-pine start (cons p1 p2))
	     (setf start nil)))
       (setf last p1)))))

(defun save-swamp ()
  (noise3D 0.0 0.0 0.0) ; first call to noise3D calls srandom
  (cseed 1) 
  (let ((*pines* nil)
	(*water-map* nil)
	(*height-map* nil)	
	(*surface-map* nil)
	(name "swamp-procedural.lua"))
    (with-open-file (*stream* name :direction :output :if-exists :supersede)
      (output "-- Generated by swamp.lisp~%")
      (save-terrain)
      (save-water)
      (save-pines)
      (save-misc)
      (values))))
