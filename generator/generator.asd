(in-package #:asdf)

(defsystem generator
  :components
  ((:module :generator
	    :pathname "."
	    :components
	    ((:file "noise")
	     (:file "swamp"	:depends-on ("noise"))
	     (:file "waterfall"	:depends-on ("swamp"))
	     (:file "forest"	:depends-on ("swamp")))))
  :depends-on (cffi))

