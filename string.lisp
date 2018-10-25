(ql:quickload :lispbuilder-sdl)
(load "load.lisp")

(use-package :vector3d)
(use-package :state3d)

(defvar *frame-rate* 30)
(defvar *damping* 1)
(defvar *dt* .01d0)
(defvar n)
(defvar k)
(defvar len)
(defvar nlen)
(defvar nodes)
(defvar count-time-y)
(defvar vibration-sign-y)
(defvar position-offset-y)
(defvar period-y)
(defvar count-time-x)
(defvar vibration-sign-x)
(defvar position-offset-x)
(defvar period-x)

(defun make-pendulum (length theta0 x y)
  (let* ((theta (* (/ theta0 180) pi))
         (velocity 0))
    (if (< length 40) (setf length 40)) ;;avoid a divide-by-zero
    (lambda ()
      (sdl:draw-filled-circle (sdl:point :x (+ (* (sin theta) length) x)
                                         :y (+ (* (cos theta) length) y))
                              5
                              :color sdl:*yellow*)
      (incf velocity (* (sqrt (/ 9.81 length )) (sin theta) (* *frame-rate* -.01)))
      (incf theta (* velocity (* *frame-rate* .01)))
      (setf velocity (* velocity *damping*)))))

(defun init (height width)
  (setf count-time-y 0)
  (setf vibration-sign-y 1)
  (setf position-offset-y 0)
  (setf period-y 100)
  (setf count-time-x 0)
  (setf vibration-sign-x 1)
  (setf position-offset-x 0)
  (setf period-x 100)
  (setf n 250)
  (setf len 100d0)
  (setf nlen (/ len (+ 4 n)))
  (setf k 10d0)
  (setf nodes (loop for i from 1 to (+ 3 n) collect
                                            (state (+ width (* i -1 nlen (/ width len))) (/ height 2d0) 0d0 0d0 0d0 0d0 1d0)))
  )

(defun string-draw ()
  (dolist (i (butlast nodes))
    (sdl:draw-filled-circle (sdl:point :x (v3x (state-pos i))
                                       :y (v3y (state-pos i)))
                            3
                            :color sdl:*yellow*)))

(defun string-update (oscil-y oscil-x)
  (if oscil-y
      (string-vibrate-y 100d0))
  (if oscil-x
      (string-vibrate-x 100d0))
  (dolist (i nodes)
    (posi i *dt*))
  (do* ((last (car nodes) (car current))
        (current (cdr nodes) (cdr current))
        (r1 (sub (state-pos last) (state-pos (car current)))
            (sub (state-pos last) (state-pos (car current))))
        (r2 (sub (state-pos (cadr current)) (state-pos (car current)))
            (sub (state-pos (cadr current)) (state-pos (car current))))
        (r1len (len r1) (len r1))
        (r2len (len r2) (len r2))
        (delr1 (* k (- r1len nlen)) (* k (- r1len nlen)))
        (delr2 (* k (- r2len nlen)) (* k (- r2len nlen)))
        (dp1 (sub (state-vel last) (state-vel (car current)))
             (sub (state-vel last) (state-vel (car current))))
        (dp2 (sub (state-vel (cadr current)) (state-vel (car current)))
             (sub (state-vel (cadr current)) (state-vel (car current))))
        (const (/ .01d0 *dt*)))
       ((eq (cddr current) nil) nil)
    (nmul r1 delr1)
    (nmul r2 delr2)
    (nmul dp1 const)
    (nmul dp2 const)
    (nadd (state-acc (car current)) r1)
    (nadd (state-acc (car current)) r2)
    (nadd (state-acc (car current)) dp1)
    (nadd (state-acc (car current)) dp2))
  (dolist (i nodes)
    (velo i *dt*)
    (nmul (state-vel i) .9999d0)))

(defun string-vibrate-y (increment-y)
  (setf increment-y (* vibration-sign-y increment-y (/ 1 period-y)))
  (if (> count-time-y period-y)
      (progn (setf vibration-sign-y (* -1 vibration-sign-y))
             (setf count-time-y 0)))
  (incf (v3y (state-pos (car nodes))) increment-y)
  (incf position-offset-y increment-y)
  (incf count-time-y))

(defun string-vibrate-x (increment-x)
  (setf increment-x (* vibration-sign-x increment-x (/ 1 period-x)))
  (if (> count-time-x period-x)
      (progn (setf vibration-sign-x (* -1 vibration-sign-x))
             (setf count-time-x 0)))
  (incf (v3x (state-pos (car nodes))) increment-x)
  (incf position-offset-x increment-x)
  (incf count-time-x))


(defun main (&optional (w 640) (h 480))
  (init h w)
  (sdl:with-init ()
    (sdl:window w h :title-caption "Pendulums"
                    :fps (make-instance 'sdl:fps-fixed))
    (setf (sdl:frame-rate) 60)
    (let ((pendulums nil)
          (oscil-y nil)
          (oscil-x nil)
          (mouse-toggle nil)
          (string-toggle t))
      (sdl:with-events ()
        (:quit-event () t)
        (:idle ()
               (sdl:clear-display sdl:*black*)
               (mapcar #'funcall pendulums)
               (if string-toggle
                   (progn
                     (string-draw)
                     (loop for i from 1 to 80 do (string-update oscil-y oscil-x))))
               (sdl:update-display))
        (:mouse-motion-event (:x x :y y)
                             (if mouse-toggle
                                 (progn (setf (v3x (state-pos (car nodes)))
                                              (coerce x 'double-float))
                                        (setf (v3y (state-pos (car nodes)))
                                              (+ y position-offset)))))
        (:mouse-button-down-event (:button button :y y)
                                  (cond
                                    ((eq button 1)
                                     (progn
                                       (setf oscil-y nil)
                                       (setf oscil-x nil)
                                       (setf mouse-toggle (not mouse-toggle))
                                       (setf position-offset-y 0d0)
                                       (setf count-time 0)
                                       (setf vibration-sign-y 1)
                                       (setf (v3y (state-pos (car nodes)))
                                             (+ y position-offset-y))))
                                    ((eq button 4)
                                     (if (> period-y 20)
                                         (incf period-y -20)
                                         (setf period-y 1)))
                                    ((eq button 5)
                                     (incf period-y 20))))
        (:key-down-event (:key key)
                         (cond ((sdl:key= key :sdl-key-escape)
                                (sdl:push-quit-event))
                               ((sdl:key= key :sdl-key-equals)
                                (if (> period-x 20)
                                    (incf period-x -20)
                                    (setf period-x 1)))
                               ((sdl:key= key :sdl-key-minus)
                                (incf period-x 20))
                               ((sdl:key= key :sdl-key-q)
                                (sdl:push-quit-event))
                               ((sdl:key= key :sdl-key-l)
                                (setf oscil-x (not oscil-x)))
                               ((sdl:key= key :sdl-key-t)
                                (setf oscil-y (not oscil-y)))
                               ((sdl:key= key :sdl-key-s)
                                (setf string-toggle (not string-toggle)))
                               ((sdl:key= key :sdl-key-m)
                                (setf mouse-toggle (not mouse-toggle)))
                               ((sdl:key= key :sdl-key-space)
                                (loop for i from 1 to 1000 do
                                  (push (make-pendulum (random (* h .85))
                                                       (+ 10 (random 45))
                                                       (round w 2)
                                                       (round h 20)) pendulums)))))))))
