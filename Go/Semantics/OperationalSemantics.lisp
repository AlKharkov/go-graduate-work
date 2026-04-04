#|
	Operational semantics for the Go language

    Last edit: 04/04/2026
|#


;;; ================================================
;;; Enviroment and Agents
;;; ================================================

(mot "env"  :at "agents" (listt "agent"))
(mot "agent"
    :at "constant value" (cot :amap "constant name" "Go value")
    :at "variable cell"  (cot :amap "identifier" "cell")              ; The relation of names to their memory locations
    :at "function value" (cot :amap "function name" "function value")
    :at "method value"   (cot :amap "method name" "method value")
    :at "type"           (cot :amap "type name" "type")               ; Types created in the program
    :at "value"          "Go value")                                  ; The last value calculated by the agent


;;; ================================================
;;; Values and names
;;; ================================================

(aclosure ac :attribute "opsem::rvalue" :type "Go value" :instance i :do i)

(aclosure ac :attribute "opsem::rvalue" :type "identifier" :instance i :do 
    (match :v (aget a "constant value" i) nil :exit (aget a "constant value" i) 
           :v (aget a "variable cell"  i) nil :exit (aget (aget a "variable cell" i) "value") 
           :v (aget a "function value" i) nil :exit (aget a "function value" i) 
           :v (aget a "method value"   i) nil :exit (aget a "method value" i)))

(aclosure ac :attribute "opsem::lvalue" :type "variable name" :instance i :agent a 
    :do (aget a "variable cell" i))


;;; ================================================
;;; Literals
;;; ================================================

;; array lit
; Отправляет вычислять значение по умолчанию для элементов массива.
(aclosure ac :attribute "opsem::rvalue" :type "array lit" :instance i :stage nil :do 
    (update-push-aclosure ac :stage "fill defaults")
    (clear-update-eval-aclosure ac :attribute "default value by type" :instance (aget i "type" "elem type"))
)
; Заполняет массив значениями по умолчанию. Отправляет вычислять явно заданные значения.
(aclosure ac :attribute "opsem::rvalue" :type "array lit" :instance i :stage "fill defaults" 
    :value v :ap i "elements" es :do 
    (match :v (null es) T :do (mo "array value" :av "type" (aget i "type") :av "elements" nil) 
    :exit (update-push-aclosure ac :stage "evaluating" :av "left" es :av "array" (make-list (aget i "type" "len") v))
          (clear-update-eval-aclosure ac :instance (aget (car es) "value")))
)
; Изменяет значение очередного элемента массива.
; Если все значения вычислены, то создаёт и возвращает значение массива. Иначе отправляет вычислять далее.
(aclosure ac :attribute "opsem::rvalue" :type "array lit" :instance i :stage "evaluating" 
    :ap ac "left" left :ap ac "array" arr :value v :ap (car left) "index" k :do 
    (let ((c arr)) (dotimes (j k (setf (car c) v)) (setf c (cdr c))))
    (match :v (null (cdr left)) T :do (mo "array value" :av "type" (aget i "type") :av "elements" arr)
    :exit (update-push-aclosure ac :av "left" (cdr left) :av "array" arr)
          (clear-update-eval-aclosure ac :instance (car (cdr left))))
)

;; slice lit
; Отправляет вычислять значение по умолчанию для элементов среза.
(aclosure ac :attribute "opsem::rvalue" :type "slice lit" :instance i :stage nil :do 
    (update-push-aclosure ac :stage "build value")
    (update-push-aclosure ac :stage "fill defaults")
    (clear-update-eval-aclosure ac :attribute "default value by type" :instance (aget i "type" "elem type"))
)
; По максимальному индексу создаёт массив. Отправляет вычислять явно заданные значения.
(aclosure ac :attribute "opsem::rvalue" :type "slice lit" :instance i :stage "fill defaults" 
    :value v :ap i "elements" es :p 0 m :do 
    (dolist (e es) (let ((k (aget e "index"))) (if (> k m) (setf m k))))
    (match :v (null es) T :do nil
    :exit (update-push-aclosure ac :stage "evaluating" :av "left" es :av "array" (make-list (1+ m) v))
          (clear-update-eval-aclosure ac :instance (aget (car es) "value")))
)
; Изменяет значение очередного элемента среза.
; Если все значения вычислены, то возвращает их в правильном порядке. Иначе отправляет вычислять далее.
(aclosure ac :attribute "opsem::rvalue" :type "slice lit" :instance i :stage "evaluating" 
    :ap ac "left" left :ap ac "array" arr :value v :p (aget (car left) "index") k :do 
    (let ((c arr)) (dotimes (j k (setf (car c) v)) (setf c (cdr c))))
    (match :v (null left) T :do (reverse arr) 
    :exit (update-push-aclosure ac :av "left" (cdr left) :av "array" arr)
          (clear-update-eval-aclosure ac :instance (car (cdr left))))
)
; Создаёт и возвращает значение среза.
(aclosure ac :attribute "opsem::rvalue" :type "slice lit" :instance i :stage "build value" 
    :value arr :ap i "type" stp :ap stp "elem type" etp :p (length arr) n :do 
    (mo "slice value" 
        :av "type" (aget i "type")
        :av "array" (mo "array value" :av "type" (mo "array type" :av "elem type" etp :av "len" n) :av "elements" arr)
        :av "offset" 0 
        :av "length" n
        :av "capacity" n)
)



















;; array lit
(aclosure ac :attribute "opsem::rvalue" :type "array lit" :instance i :stage nil 
    :ap i "elements" es :do 
    (update-push-aclosure ac :stage "build value")
    (match :v (null es) T :do nil 
    :exit (update-push-aclosure ac :stage "evaluating" :av "left" (cdr es) :av "done" nil)
          (clear-update-eval-aclosure ac :instance (car es)))
)
; Вычисляет значение элемента массива. Возвращает вычисленный целиком список элементов.
(aclosure ac :attribute "opsem::rvalue" :type "array lit" :instance i :stage "evaluating" 
    :ap ac "left" left :ap ac "done" d :value v :p (cons v d) lst :do 
    (match :v (null left) T :do lst
    :exit (update-push-aclosure ac :av "left" (cdr left) :av "done" lst)
          (clear-update-eval-aclosure ac :instance (car left)))
)
; Если все значения заданы явно, то возвращает значение массива. 
; Иначе отправляет вычислять значение элемента по умолчанию.
(aclosure ac :attribute "opsem::rvalue" :type "array lit" :instance i :stage "build value" 
    :value es :p (length es) les :ap i "type" tp :ap i "elements" es :ap tp "len" n :do 
    (match :v (= n les) T :do (mo "array value" :av "type" tp :av "elements" (reverse es))
    :exit (update-push-aclosure ac :stage "filling defaults" :av "elements" es)
          (clear-update-eval-aclosure ac :attribute "default value by type" :instance (aget tp "elem type")))
)
; Добавляет нужное количество не заданных явно элементов, возвращает значение массива.
(aclosure ac :attribute "opsem::rvalue" :type "array lit" :instance i :stage "filling defaults" 
    :ap ac "elements" es :value dv :p (length es) les :ap i "type" tp :p (length (aget i "elements")) n :do 
    (dotimes (i les) (setf es (cons dv es)))
    (mo "array value" :av "type" tp :av "elements" (reverse es))
)

;; slice lit
(aclosure ac :attribute "opsem::rvalue" :type "slice lit" :instance i :stage nil 
    :ap i "elements" es :ap i "type" stp :ap stp "elem type" etp :do 
    (update-push-aclosure ac :stage "build value")
    (match :v (null es) T :do nil
    :exit (update-push-aclosure ac :stage "evaluating" :av "left" (cdr es) :av "done" nil)
          (clear-update-eval-aclosure ac :instance (car es)))
)
; Вычисляет значение элемента среза. Возвращает вычисленный целиком список элементов.
(aclosure ac :attribute "opsem::rvalue" :type "slice lit" :instance i :stage "evaluating" 
    :ap ac "left" left :ap ac "done" d :value v :p (cons v d) lst :do 
    (match :v (null left) T :do lst 
    :exit (update-push-aclosure ac :av "left" (cdr left) :av "done" lst)
          (clear-update-eval-aclosure ac :instance (car left)))
)
; Создаёт и возвращает значение среза
(aclosure ac :attribute "opsem::rvalue" :type "slice lit" :instance i :stage "build value" 
    :ap i "type" stp :ap stp "elem type" etp :value lst :p (length lst) n :do 
    (mo "slice value" 
    :av "type" stp
    :av "array" (mo "array value" :av "type" (mo "array type" :av "elem type" etp :av "len" n) :av "elements" (reverse lst))
    :av "offset" 0 
    :av "length" 0 
    :av "capacity" n)
)

;; struct lit
(aclosure ac :attribute "opsem::rvalue" :type "struct lit" :instance i :stage nil 
    :ap i "fields" fs :ap i "values" vs :do 
    (update-push-aclosure ac :stage "create value")
    (match :v (null vs) T :do nil :exit 
        (update-push-aclosure ac :stage "evaluating" :av "left" (cdr vs) :av "done" nil)
        (clear-update-eval-aclosure ac :instance (car fs)))
)
; Вычисляет значение поля. Возвращает список вычисленных значений.
(aclosure ac :attribute "opsem::rvalue" :type "struct lit" :instance i :stage "evaluating" 
    :ap ac "left" left :ap ac "done" d :value v :p (cons v d) lst :do 
    (match :v (null left) T :do lst 
    :exit (update-push-aclosure ac :av "left" (cdr left) :av "done" lst)
          (clear-update-eval-aclosure ac :instance (car left)))
)
; Если значения всех полей указаны явно, то создаёт и возвращает значение экземпляра структуры.
; Иначе отправляет вычислять значение поля по умолчанию.
(aclosure ac :attribute "opsem::rvalue" :type "struct lit" :instance i :stage "create value" 
    :value lst :ap i "type" stp :ap i "fields" fs :ap (cot :amap "field name" "Go value") fv :do 
    (if (null fs) (setf fs (aget stp "ordered")))  ; если заданы без имён, то имена полей опеределяются порядком
    (setf left (do ((names fs (cdr names)) (values (reverse lst) (cdr values))) 
                   ((null values) names) 
                   (setf fv (aset fv (car names) (car values)))))
    (match :v (null left) T :do (mo "struct value" :av "type" stp :av "fields" fv)
    :exit (update-push-aclosure ac :stage "filling defaults" :av "left" left :av "done" fv)
          (clear-update-eval-aclosure ac :attribute "default value by type" :instance (aget stp "fields" (car left))))
)
; Вычисляет значение поля по умолчанию. Создаёт и возвращает значение экземпляра структуры.
(aclosure ac :attribute "opsem::rvalue" :type "struct lit" :instance i :stage "filling defaults" 
    :ap ac "left" left :av ac "done" d :value v :p (aset d (car left) v) fv :ap i "type" stp :do 
    (match :v (null (cdr left)) T :do (mo "struct value" :av "type" stp :av "fields" fv)
    :exit (update-push-aclosure ac :av "left" (cdr left) :av "done" fv)
          (clear-update-eval-aclosure ac :attribute "default value by type" :instance (aget stp "fields" (car (cdr left)))))
)

































;;; Blocks
(aclosure ac :attribute "opsem" :type "block" :instance i :stage nil :do
    (update-push-aclosure ac :stage "variable handling" :av "current" (attributes (aget i "variable location")))
    (clear-update-eval-aclosure ac :stage "evaluating statement")
)
(aclosure ac :attribute "opsem" :type "block" :instance i :stage "evaluating statement" 
    :ap i "statements" sts :v (null sts) nil :do
    (update-push-aclosure ac :av "statements" (cdr sts))
    (clear-update-eval-aclosure ac :instance (car sts) :av "block" i)  ; Для добавления затенённых в "block"->"variable location"
)
(aclosure ac :attribute "opsem" :type "block" :instance i :stage "variable handling" :agent a
    :ap i "variable location" vl :ap ac "current" lst :v (null lst) nil :p (car lst) name :do 
    (aset a "location" name (aget vl name))  ; Возвращаем прежнее значение переменной
    (clear-update-eval-aclosure ac :av "current" (cdr lst))
)


;;; Declarations
(aclosure ac :attribute "opsem" :type "type decl" :instance i :agent a :do (aset a "type" (aget i "name") (aget i "type")))

(aclosure ac :attribute "opsem" :type "const decl" :instance i :stage nil :do 
    (update-push-aclosure ac :stage "declarating" :av "current" 0)
    (clear-update-eval-aclosure ac :instance (car (aget i "values")))
)
(aclosure ac :attribute "opsem" :type "const decl" :instance i :stage "declarating" :agent a 
    :ap ac "current" k :ap i "names" ns :ap i "types" ts :ap "values" vs :value v :v (< k (length ns)) :do 
    (aset a "constant value" (nth k ns))
    (update-push-aclosure ac :av "current" (+ k 1))
    (clear-update-eval-aclosure ac :instance (nth k vs))

)


(mot "const decl" :at "names" (listt "constant name") :at "types" (listt "type") :av "values" (listt "expression"))

























(aclosure ac :attribute "opsem" :type "var decl" :instance i :stage nil :do 
    (update-push-aclosure ac :stage "declarating" :av "current" 0)
    (clear-update-eval-aclosure ac :instance (car (aget i "values")))
)
(aclosure ac :attribute "opsem" :type "var decl" :instance i :agent a :stage "declarating" 
    :ap ac "current" k :ap i "names" ns :p (length ns) n :v (< k n) T :p (nth k ns) name :p (nth k (aget i "types")) tp :value v :do 
    (aset a "location" name (mo "location" :av "type" tp :av "value" v))
    (update-push-aclosure ac :stage "declarating" :av "current" (+ k 1) :av "len" n)
    (clear-update-eval-aclosure ac :instance (nth (+ k 1) (aget i "values")))
)

(aclosure ac :attribute "opsem" :type "function decl" :instance i :stage nil :do 
    (update-push-aclosure ac :stage "get function type")
    (clear-update-eval-aclosure ac :instance (aget i "signature"))
)
(aclosure ac :attribute "opsem" :type "function decl" :instance i :stage "get function type" 
    :value sgn :p (mo "function lit" :av "signature" sgn :av "body" "block") fl
    (update-push-aclosure ac :stage "exit function decl" :av "function lit" fl)
    (clear-update-eval-aclosure ac :instance fl :attribute "default type by value")
)
(aclosure ac :attribute "opsem" :type "function decl" :instance i :stage "exit function decl" :value tp :agent a :do
    (aset a "location" (aget i "name") (mo "location" :av "type" tp :av "value" (aget ac "function lit")))
)

(aclosure ac :attribute "opsem" :type "signature" :instance i :stage nil :do 
    (update-push-aclosure ac :stage "get variadic parameter")
    (clear-update-eval-aclosure ac :instance (aget i "parameters") :attribute "type substitution")
)
(aclosure ac :attribute "opsem" :type "signature" :instance i :stage "get variadic parameter" :value ps :do
    (update-push-aclosure ac :stage "get result" :av "parameters" ps)
    (clear-update-eval-aclosure ac :instance (aget i "variadic parameter") :attribute "type substitution")
)
(aclosure ac :attribute "opsem" :type "signature" :instance i :stage "get result" :value vp :do 
    (update-push-aclosure ac :stage "exit signature" :av "variadic parameter" vp)  ; ac contains "parameters"
    (clear-update-eval-aclosure ac :instance (aget i "result") :attribute "type substitution")
)
(aclosure ac :attribute "opsem" :type "signature" :instance i :stage "exit signature" :value r :do 
    (mo "signature" :av "parameters" (aget ac "parameters") :av "variadic parameter" (aget ac "variadic parameter") :av "result" r)
)

(mot "signature" :at "parameters" (listt "parameter decl") :at "variadic parameter" "variadic decl" :at "result" (uniont (listt "type") (listt "parameter decl")))
(mot "function decl" :at "name" "function name" :at "signature" "signature" :at "body" "block")
(mot "function lit" :at "signature" "signature" :at "body" "block")  ; func(a int) bool { return a < 0 }
(mot "function type" :at "signature" "type signature")


;;; Expressions
;; Operands
(aclosure ac "opsem" "composite literal" i :do ...)  ; TODO
(aclosure ac "opsem" "keyed element" i :do i)
(aclosure ac "opsem" "function literal" i :do ...)  ; TODO...
(aclosure ac "opsem" "operand[T]" i :do
    ; Создать новый объект, с подставленным типом
    ; Limitations prohibit - предварительно вычисляем
)
(aclosure ac "opsem::any" "(expression)" i :ap i "expression" e :do (clear-update-eval-aclosure ac "instance" e))
;primary expressions
(aclosure ac "opsem::any" "conversion" i :stage nil
    :ap i "expression" e :do
    (update-push-aclosure ac :stage "type")
    (clear-update-eval-aclosure ac :instance e)
)
(aclosure ac "opsem::any" "conversion" i :stage "type" :value e
    :ap i "type" t :do
    (update-push-aclosure ac :stage "access" :av "expression" e)
    (clear-update-eval-aclosure ac :instance t)
)
(aclosure ac "opsem::any" "conversion" i :stage "access" :value t
    :ap ac "expression" e :do
    ; Собственно приведение типа
    ; TODO
)

(aclosure "opsem::rvalue" "method expression" i ac ...)  ; TODO
;(mot "struct" :at "fields" (listt "field valued"))                   ; Куда это?
;(mot "field valued" :at "name" "identifier" :at "value" "Go value")  ; Определение экземпляра структурного объекта
(aclosure ac "opsem" "selector expression" i :stage nil :do
    (update-push-aclosure ac "stage" "access")
    (clear-update-eval-aclosure ac "instance" (aget i "expression"))
)
(aclosure ac "opsem" "selector expression" i :stage "access" :value e :ap i "selector" name :do
    ; To be continued...
)

(alcosure ac "opsem::lvalue" "index expr" i :stage nil :ap i "list" l :do
    (update-push-aclosure ac :stage "index evaluation")
    (clear-update-eval-aclosure ac :instance l)
)
(alcosure ac "opsem::lvalue" "index expr" i :stage "index evaluation" :value l :ap i "index" ind :do
    (update-push-aclosure ac :stage "access" :av "list" l)
    (clear-update-eval-aclosure ac :attribute "opsem::rvalue" :instance ind)
)
(aclosure ac "opsem::lvalue" "index expr" i :stage "access"
    :value ind :ap ac "list" l :do
    ; TODO <- array decl
)
(aclosure ac "opsem::rvalue" "index expr" i :do ...)  ; TODO
(aclosure ac "opsem" "slice expr" i :do ...)  ; TODO
(aclosure ac "opsem" "slice" i :do ...)  ; TODO
(aclosure ac "opsem::rvalue" "function call" i :do ...) ; TODO&
(aclosure ac "opsem" "argument" i :do ...) ; TODO
; unary expressions
(aclosure ac "opsem::rvalue" "+1" i :stage nil :ap i 1 e :do
    (update-push-aclosure ac "stage" "access")
    (clear-update-eval-aclosure ac "instance" e)
)
(aclosure ac "opsem::rvalue" "+1" i :stage "access" :value e :do (+ 0 e))
(aclosure ac "opsem::rvalue" "-1" i :stage nil :ap i 1 e :do
    (update-push-aclosure ac "stage" "access")
    (clear-update-eval-aclosure ac "instance" e)
)
(aclosure ac "opsem::rvalue" "-1" i :stage "access" :value e :do (- 0 e))
; (aclosure ac "opsem::rvalue" "^1" i :stage nil :ap i 1 e :do
;     (update-push-aclosure ac "stage" "access")
;     (clear-update-eval-aclosure ac "instance" e)
; )
; (aclosure ac "opsem::rvalue" "^1" i :stage "access" :value e :do (logxor 0 e))
(aclosure ac "opsem::rvalue" "!1" i :stage nil :ap i 1 e :do
    (update-push-aclosure ac "stage" "access")
    (clear-update-eval-aclosure ac "instance" e)
)   
(aclosure ac "opsem::rvalue" "!1" i :stage "access" :value e :do (= nil e))
(aclosure ac "opsem::lvalue" "*1" i :stage nil :ap i 1 e :do
    (update-push-aclosure ac "stage" "access")
    (clear-update-eval-aclosure ac "instance" e)
)
(aclosure ac "opsem::lvalue" "*1" i :stage "access" :value e :do ...)  ; TODO after question
(aclosure ac "opsem::rvalue" "*1" i :stage nil :ap i 1 e :do
    (update-push-aclosure ac "stage" "access")
    (clear-update-eval-aclosure ac "instance" e)
)
(aclosure ac "opsem::rvalue" "*1" i :stage "access" :value e :do ...)  ; TODO after question
(aclosure ac "opsem::rvalue" "&1" i :stage nil :ap i 1 e :do
    (update-push-aclosure ac "stage" "access")
    (clear-update-eval-aclosure ac "instance" e)
)
(aclosure ac "opsem::rvalue" "&1" i :stage "access" :value e :do 
    ; Создаем ссылку на вычисленную переменную "e"
    ; TODO after question
)
(aclosure ac "opsem::rvalue" "<-1" i :stage nil :ap i 1 e :do
    (update-push-aclosure ac "stage" "access")
    (clear-update-eval-aclosure ac "instance" e)
)
(aclosure ac "opsem::rvalue" "<-1" i :stage "access" :value e :do
    ; Вернуть значение из канала "e"
    ; TODO after decl channel
)
;binary expressions
(aclosure ac "opsem::rvalue" "1||2" i :stage nil :ap i 1 e1 :do
    (update-push-aclosure ac "stage" 2)
    (clear-update-eval-aclosure ac "instance" e1)
)
(aclosure ac "opsem::rvalue" "1||2" i :stage 2 :value e1 :ap i 2 e2 :do
    (match :v e1 T :do T :exit
        (update-push-aclosure ac :av "stage" "access" :av "e1" e1)
        (clear-update-eval-aclosure ac "instance" e2)
    )
)
(aclosure ac "opsem::rvalue" "1||2" i :stage "access" :ap ac "e1" e1 :value e2 :do (or e1 e2))
(aclosure ac "opsem::rvalue" "1&&2" i :stage nil :ap i 1 e1 :do
    (update-push-aclosure ac "stage" 2)
    (clear-update-eval-aclosure ac "instance" e1)
)
(aclosure ac "opsem::rvalue" "1&&2" i :stage 2 :value e1 :ap i 2 e2 :do
    (match :v e1 nil :do nil :exit
        (update-push-aclosure ac :av "stage" "access" :av "e1" e1)
        (clear-update-eval-aclosure ac "instance" e2)
    )
)
(aclosure ac "opsem::rvalue" "1&&2" i :stage "access" :value e2 :ap ac "e1" e1 :do (and e1 e2))
;;binary multiplication expressions
(aclosure ac "opsem::rvalue" "1*2" i :stage nil :ap i 1 e1 :do
    (update-push-aclosure ac "stage" 2)
    (clear-update-eval-aclosure ac "instance" e1)
)
(aclosure ac "opsem::rvalue" "1*2" i :stage 2 :value e1 :ap i 2 e2 :do
    (update-push-aclosure ac :av "stage" "access" :av "e1" e1)
    (clear-update-eval-aclosure ac "instance" e2)
)
(aclosure ac "opsem::rvalue" "1*2" i :stage "access" :value e2 :ap ac "e1" e1 :do (* e1 e2))
(aclosure ac "opsem::rvalue" "1/2" i :stage nil :ap i 1 e1 :do
    (update-push-aclosure ac "stage" 2)
    (clear-update-eval-aclosure ac "instance" e1)
)
(aclosure ac "opsem::rvalue" "1/2" i :stage 2 :value e1 :ap i 2 e2 :do
    (update-push-aclosure ac :av "stage" "access" :av "e1" e1)
    (clear-update-eval-aclosure ac "instance" e2)
)
(aclosure ac "opsem::rvalue" "1/2" i :stage "access" :value e2 :ap ac "e1" e1 :do (/ e1 e2))
(aclosure ac "opsem::rvalue" "1%2" i :stage nil :ap i 1 e1 :do
    (update-push-aclosure ac "stage" 2)
    (clear-update-eval-aclosure ac "instance" e1)
)
(aclosure ac "opsem::rvalue" "1%2" i :stage 2 :value e1 :ap i 2 e2 :do
    (update-push-aclosure ac :av "stage" "access" :av "e1" e1)
    (clear-update-eval-aclosure ac "instance" e2)
)
(aclosure ac "opsem::rvalue" "1%2" i :stage "access" :value e2 :ap ac "e1" e1 :do (mod e1 e2))
(aclosure ac "opsem::rvalue" "1<<2" i :stage nil :ap i 1 e1 :do
    (update-push-aclosure ac "stage" 2)
    (clear-update-eval-aclosure ac "instance" e1)
)
(aclosure ac "opsem::rvalue" "1<<2" i :stage 2 :value e1 :ap i 2 e2 :do
    (update-push-aclosure ac :av "stage" "access" :av "e1" e1)
    (clear-update-eval-aclosure ac "instance" e2)
)
(aclosure ac "opsem::rvalue" "1<<2" i :stage "access" :value e2 :ap ac "e1" e1 :do (ash e1 e2))
(aclosure ac "opsem::rvalue" "1>>2" i :stage nil :ap i 1 e1 :do
    (update-push-aclosure ac "stage" 2)
    (clear-update-eval-aclosure ac "instance" e1)
)
(aclosure ac "opsem::rvalue" "1>>2" i :stage 2 :value e1 :ap i 2 e2 :do
    (update-push-aclosure ac :av "stage" "access" :av "e1" e1)
    (clear-update-eval-aclosure ac "instance" e2)
)
(aclosure ac "opsem::rvalue" "1>>2" i :stage "access" :value e2 :ap ac "e1" e1 :do (ash e1 (- e2)))
(aclosure ac "opsem::rvalue" "1&2" i :stage nil :ap i 1 e1 :do
    (update-push-aclosure ac "stage" 2)
    (clear-update-eval-aclosure ac "instance" e1)
)
(aclosure ac "opsem::rvalue" "1&2" i :stage 2 :value e1 :ap i 2 e2 :do
    (update-push-aclosure ac :av "stage" "access" :av "e1" e1)
    (clear-update-eval-aclosure ac "instance" e2)
)
(aclosure ac "opsem::rvalue" "1&2" i :stage "access" :value e2 :ap ac "e1" e1 :do (logand e1 e2))
(aclosure ac "opsem::rvalue" "1&^2" i :stage nil :ap i 1 e1 :do
    (update-push-aclosure ac "stage" 2)
    (clear-update-eval-aclosure ac "instance" e1)
)
(aclosure ac "opsem::rvalue" "1&^2" i :stage 2 :value e1 :ap i 2 e2 :do
    (update-push-aclosure ac :av "stage" "access" :av "e1" e1)
    (clear-update-eval-aclosure ac "instance" e2)
)
(aclosure ac "opsem::rvalue" "1&^2" i :stage "access" :value e2 :ap ac "e1" e1 :do (logand (logxor e1 e2) (logeqv e2 0)))
;;binary addition expressions
(aclosure ac "opsem::rvalue" "1+2" i :stage nil :ap i 1 e1 :do
    (update-push-aclosure ac "stage" 2)
    (clear-update-eval-aclosure ac "instance" e1)
)
(aclosure ac "opsem::rvalue" "1+2" i :stage 2 :value e1 :ap i 2 e2 :do
    (update-push-aclosure ac :av "stage" "access" :av "e1" e1)
    (clear-update-eval-aclosure ac "instance" e2)
)
(aclosure ac "opsem::rvalue" "1+2" i :stage "access" :value e2 :ap ac "e1" e1 :do (+ e1 e2))
(aclosure ac "opsem::rvalue" "1-2" i :stage nil :ap i 1 e1 :do
    (update-push-aclosure ac "stage" 2)
    (clear-update-eval-aclosure ac "instance" e1)
)
(aclosure ac "opsem::rvalue" "1-2" i :stage 2 :value e1 :ap i 2 e2 :do
    (update-push-aclosure ac :av "stage" "access" :av "e1" e1)
    (clear-update-eval-aclosure ac "instance" e2)
)
(aclosure ac "opsem::rvalue" "1-2" i :stage "access" :value e2 :ap ac "e1" e1 :do (- e1 e2))
(aclosure ac "opsem::rvalue" "1|2" i :stage nil :ap i 1 e1 :do
    (update-push-aclosure ac "stage" 2)
    (clear-update-eval-aclosure ac "instance" e1)
)
(aclosure ac "opsem::rvalue" "1|2" i :stage 2 :value e1 :ap i 2 e2 :do
    (update-push-aclosure ac :av "stage" "access" :av "e1" e1)
    (clear-update-eval-aclosure ac "instance" e2)
)
(aclosure ac "opsem::rvalue" "1|2" i :stage "access" :value e2 :ap ac "e1" e1 :do (logior e1 e2))
(aclosure ac "opsem::rvalue" "1^2" i :stage nil :ap i 1 e1 :do
    (update-push-aclosure ac "stage" 2)
    (clear-update-eval-aclosure ac "instance" e1)
)
(aclosure ac "opsem::rvalue" "1^2" i :stage 2 :value e1 :ap i 2 e2 :do
    (update-push-aclosure ac :av "stage" "access" :av "e1" e1)
    (clear-update-eval-aclosure ac "instance" e2)
)
(aclosure ac "opsem::rvalue" "1^2" i :stage "access" :value e2 :ap ac "e1" e1 :do (logxor e1 e2))
;;relation expressions
(aclosure ac "opsem::rvalue" "1==2" i :stage nil :ap i 1 e1 :do
    (update-push-aclosure ac "stage" 2)
    (clear-update-eval-aclosure ac "instance" e1)
)
(aclosure ac "opsem::rvalue" "1==2" i :stage 2 :value e1 :ap i 2 e2 :do
    (update-push-aclosure ac :av "stage" "access" :av "e1" e1)
    (clear-update-eval-aclosure ac "instance" e2)
)
(aclosure ac "opsem::rvalue" "1==2" i :stage "access" :value e2 :ap ac "e1" e1 :do (= e1 e2))
(aclosure ac "opsem::rvalue" "1!=2" i :stage nil :ap i 1 e1 :do
    (update-push-aclosure ac "stage" 2)
    (clear-update-eval-aclosure ac "instance" e1)
)
(aclosure ac "opsem::rvalue" "1!=2" i :stage 2 :value e1 :ap i 2 e2 :do
    (update-push-aclosure ac :av "stage" "access" :av "e1" e1)
    (clear-update-eval-aclosure ac "instance" e2)
)
(aclosure ac "opsem::rvalue" "1!=2" i :stage "access" :value e2 :ap ac "e1" e1 :do (/= e1 e2))
(aclosure ac "opsem::rvalue" "1<2" i :stage nil :ap i 1 e1 :do
    (update-push-aclosure ac "stage" 2)
    (clear-update-eval-aclosure ac "instance" e1)
)
(aclosure ac "opsem::rvalue" "1<2" i :stage 2 :value e1 :ap i 2 e2 :do
    (update-push-aclosure ac :av "stage" "access" :av "e1" e1)
    (clear-update-eval-aclosure ac "instance" e2)
)
(aclosure ac "opsem::rvalue" "1<2" i :stage "access" :value e2 :ap ac "e1" e1 :do (< e1 e2))
(aclosure ac "opsem::rvalue" "1<=2" i :stage nil :ap i 1 e1 :do
    (update-push-aclosure ac "stage" 2)
    (clear-update-eval-aclosure ac "instance" e1)
)
(aclosure ac "opsem::rvalue" "1<=2" i :stage 2 :value e1 :ap i 2 e2 :do
    (update-push-aclosure ac :av "stage" "access" :av "e1" e1)
    (clear-update-eval-aclosure ac "instance" e2)
)
(aclosure ac "opsem::rvalue" "1<=2" i :stage "access" :value e2 :ap ac "e1" e1 :do (<= e1 e2))
(aclosure ac "opsem::rvalue" "1>2" i :stage nil :ap i 1 e1 :do
    (update-push-aclosure ac "stage" 2)
    (clear-update-eval-aclosure ac "instance" e1)
)
(aclosure ac "opsem::rvalue" "1>2" i :stage 2 :value e1 :ap i 2 e2 :do
    (update-push-aclosure ac :av "stage" "access" :av "e1" e1)
    (clear-update-eval-aclosure ac "instance" e2)
)
(aclosure ac "opsem::rvalue" "1>2" i :stage "access" :value e2 :ap ac "e1" e1 :do (> e1 e2))
(aclosure ac "opsem::rvalue" "1>=2" i :stage nil :ap i 1 e1 :do
    (update-push-aclosure ac "stage" 2)
    (clear-update-eval-aclosure ac "instance" e1)
)
(aclosure ac "opsem::rvalue" "1>=2" i :stage 2 :value e1 :ap i 2 e2 :do
    (update-push-aclosure ac :av "stage" "access" :av "e1" e1)
    (clear-update-eval-aclosure ac "instance" e2)
)
(aclosure ac "opsem::rvalue" "1>=2" i :stage "access" :value e2 :ap ac "e1" e1 :do (>= e1 e2))


;;; Statements
; To be soon
