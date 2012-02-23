(cffi:define-foreign-library machine 
    (:unix "./machine.so"))
   
(cffi:use-foreign-library machine)

(export 'noise3D)
(cffi:defcfun ("noise3D" noise3D) :float
  (x :float)
  (y :float)
  (z :float))

(export 'sfloat)
(defun sfloat (value) (coerce value 'single-float))

(export 'cseed)
(cffi:defcfun ("cseed" cseed) :void
  (seed :unsigned-int))

(export 'crandom)
(cffi:defcfun ("crandom" crandom) :int
  (seed :unsigned-int))

(export 'random-elt)
(defun random-elt (list)
  (elt list (crandom (length list))))