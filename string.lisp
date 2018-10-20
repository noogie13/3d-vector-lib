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
(defvar vibration-sign)
(defvar count-time)
(defvar position-offset)
(defvar period)

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
  (setf vibration-sign 1)
  (setf position-offset 0)
  (setf period 100)
  (setf n 250)
  (setf len 100d0)
  (setf nlen (/ len (+ 4 n)))
  (setf k 10d0)
  (setf nodes (loop for i from 1 to (+ 3 n) collect
                                            (state (+ width (* i -1 nlen (/ width len))) (/ height 2d0) 0d0 0d0 0d0 0d0 1d0)))
  (setf count-time 0))

(defun string-draw ()
  (dolist (i (butlast nodes))
    (sdl:draw-filled-circle (sdl:point :x (v3x (state-pos i))
                                       :y (v3y (state-pos i)))
                            3
                            :color sdl:*yellow*)))

(defun string-update ()
  (string-vibrate 20d0)
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

(defun string-vibrate (increment)
  (setf increment (* vibration-sign increment (/ 1 period)))
  (if (> count-time period)
      (progn (setf vibration-sign (* -1 vibration-sign))
             (setf count-time 0)))
  (incf (v3y (state-pos (car nodes))) increment)
  (incf position-offset increment)
  (incf count-time))

(defun main (&optional (w 640) (h 480))
  (init h w)
  (sdl:with-init ()
    (sdl:window w h :title-caption "Pendulums"
                    :fps (make-instance 'sdl:fps-fixed))
    (setf (sdl:frame-rate) 60)
    (let ((pendulums nil))
      (sdl:with-events ()
        (:quit-event () t)
        (:idle ()
               (sdl:clear-display sdl:*black*)
               (mapcar #'funcall pendulums) ;;Draw all the pendulums
               (string-draw)
               (loop for i from 1 to 80 do (string-update))
               (sdl:update-display))
        (:mouse-motion-event (:state state :x x :y y :x-rel x-rel :y-rel y-rel)
                             (setf (v3x (state-pos (car nodes))) (coerce x 'double-float))
                             (setf (v3y (state-pos (car nodes)))
                                   (+ y position-offset)))
        (:mouse-button-down-event (:button button :state state :x x :y y)
                                  (cond ((eq button 4)
                                         (incf period -20)))
                                  (cond ((eq button 5)
                                         (incf period 20))))
        (:key-down-event (:key key)
                         (cond ((sdl:key= key :sdl-key-escape)
                                (sdl:push-quit-event))
                               ((sdl:key= key :sdl-key-q)
                                (sdl:push-quit-event))
                               ((sdl:key= key :sdl-key-w)
                                (incf period 40))
                               ((sdl:key= key :sdl-key-s)
                                (incf period -40))
                               ((sdl:key= key :sdl-key-space)
                                (loop for i from 1 to 1000 do
                                  (push (make-pendulum (random (* h .85))
                                                       (+ 10 (random 45))
                                                       (round w 2)
                                                       (round h 20)) pendulums)))))))))