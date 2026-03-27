#|
	Operational semantics for the Go language

    Last edit: 27/03/2026
|#

; ; Quest 1
; (mot "someType" :at "value" (listt "T"))  ; Некоторый абстрактный тип, атрибутом которого является список
; (alcosure ac :attribute "test" :type "someType" :instance i :stage nil :do
;     (update-push-aclosure ac :stage "exit")
;     (clear-update-eval-aclosure ac :instance (aget i "value"))
; )
; (aclosure ac :attribute "test" :type (listt "T") :instance i :do  ; 1) Можно ли тип (listt "T") указывать?
;     (setf (nth 0 i) "current")  ; 2) Это изменит только локально или в следующем замыкании оно будет изменённое(см. вопрос ниже)?
; )
; (alcosure ac :attribute "test" :type "someType" :instance i :stage "exit" :do
;     ; 2) Будет ли тут тоже (nth 0 (aget i "value")) == "current"?
; )


;;; Type substitution


; Quest 2: (nil nil 1 1 1 nil nil 2 3 4) -> 
;       -> ( 1   1  1 1 1  2   2  2 3 4), где 1, 2, 3, 4 - некоторые типы
;
; func(a, b, c int, d float64, e, f bool) - "реальный" пример
; func(a int, b int, c int, d float64, e bool, f bool)
;variant 1 (возвращает изменённый массив)
; Проходит список с конца, запоминая последнее не-nil значение. Если встречает nil, то заменяет его на запомненное.
(aclosure ac :attribute "type substitution" :type (listt "type") :instance i :do
    (let ((reversed-list (reverse i)) (last-non-nil nil) (result nil))
    (dolist (e reversed-list)
        (if (null e) (push last-non-nil result)
            (progn (setq last-non-nil e) (push last-non-nil result))))
    result)
)
;variant 2 (изменяет исходный массив)
(aclosure ac :attribute "type substitution" :type (listt "type") :instance i :do
    (let ((last-non-nil nil)) 
        (loop for k from (1- (length i)) downto 0 do 
            (let ((item (nth k i))) (if item 
                (setf last-non-nil item) 
                (setf (nth k i) last-non-nil)))) 
    i)
)
;variant 3 (ABML-подход?)
(aclosure ac :attribute "type substitution" :type (listt "type") :instance i :stage nil :do
    (update-push-aclosure ac :stage "exit (listt 'type')")
    (clear-update-eval-aclosure ac :stage "iterating" :av "current" nil :av "left" (reverse i) :av "last non nil" nil)
)
(aclosure ac :attribute "type substitution" :type (listt "type") :instance i :stage "iterating" 
    :ap ac "current" cur :ap ac "left" left :ap ac "last non nil" v :do 
    (match :v (null left) T :do cur
        :exit (match :v (car left) nil 
            :do (clear-update-eval-aclosure ac :av "current" (cons v cur) :av "left" (cdr left) :av "last non nil" v)
            :exit (clear-update-eval-aclosure ac 
                :av "current" (cons (car left) cur) :av "left" (cdr left) :av "last non nil" (car left))
        )
    )
)
(aclosure ac :attribute "type substitution" :type (listt "type") :instance i :stage "exit (listt 'type')" :value v :do v)
;END variants



(aclosure ac :attribute "type substitution" :type (listt "parameter decl") :instance i :p (reverse i) ri :do 
    (match :v (null i) T 
        :do i
        :exit (update-push-aclosure ac :stage "substituting parameters" :av "current" nil :av "left" ri)
        (clear-update-eval-aclosure ac :instance (car ri))
    )
)
(aclosure ac :attribute "type substitution" :type (listt "parameter decl") :instance i :stage "substituting parameters" 
    :ap ac "current" lst :ap ac "left" left :value now :do 
    (match :v (null left) T 
        :do (append now lst) 
        :exit (update-push-aclosure ac :av "current" (append now lst) :av "left" (cdr left)) 
        (clear-update-eval-aclosure ac :instance (car left))
    )
)
; "parameter decl" -> (listt "single param decl")
(aclosure ac :attribute "type substitution" :type "single param decl" :instance i :do (list i))

(aclosure ac :attribute "type substitution" :type "multi param decl" :instance i :stage nil :do
    (clear-update-eval-aclosure ac :stage "creating singles" :av "current" nil :av "left" (reverse (aget i "names")))
)
(aclosure ac :attribute "type substitution" :type "multi param decl" :instance i :stage "creating singles" 
    :ap ac "current" lst :ap ac "left" left :ap i "type" tp :do 
    (match :v (null left) T 
        :do lst 
        :exit (clear-update-eval-aclosure ac 
            :av "current" (cons (mo "single param decl" :av "name" (car left) :av "type" tp) lst) 
            :av "left" (cdr left))
    )
)

(aclosure ac :attribute "type substitution" :type "signature" :instance i :stage nil :do 
    (update-push-aclosure ac :stage "substituting result")
    (clear-update-eval-aclosure ac :instance (aget i "parameters"))
)
(aclosure ac :attribute "type substitution" :type "signature" :instance i :stage "substituting result" 
    :value ps :do 
    (update-push-aclosure ac :stage "exit signature" :av "parameters" ps)
    (clear-update-eval-aclosure ac :instance result)
)
(aclosure ac :attribute "type substitution" :type "signature" :instance i :stage "exit signature" 
    :ap ac "parameters" ps :value r :do 
    (mo "signature" :av "parameters" ps :av "variadic parameter" (aget i "variadic parameter") :av "result" r)
)

(aclosure ac :attribute "type substitution" :type "function lit" :instance i :stage nil :do
    (update-push-aclosure ac :stage "exit function lit")
    (clear-update-eval-aclosure ac :instance (aget i "signature"))
)
(aclosure ac :attribute "type substitution" :type "function lit" :instance i :stage "exit function lit" :value sgn :do 
    (mo "function lit" :av "signature" sgn :av "body" (aget i "body"))
)

(aclosure ac :attribute "type substitution" :type "var decl" :instance i :stage nil :do 
    (update-push-aclosure ac :stage "exit var decl")
    (clear-update-eval-aclosure ac :instance (aget i "types"))
)
(aclosure ac :attribute "type substitution" :type "var decl" :instance i :stage "exit var decl" :value ts :do 
    (mo "var decl" :av "names" (aget i "names") :av "types" ts :av "values" (aget i "values"))
)


;;; default type by value
(aclosure ac :attribute "default type by value" :type int :do (mo "int type"))
(aclosure ac :attribute "default type by value" :type real :do (mo "float type"))
(aclosure ac :attribute "default type by value" :type "true" :do (mo "bool type"))
(aclosure ac :attribute "default type by value" :type "false" :do (mo "bool type"))
(aclosure ac :attribute "default type by value" :type string :do (mo "string type"))
(aclosure ac :attribute "default type by value" :type "complex constant" :do (mo "complex type"))
(aclosure ac :attribute "default type by value" :type "array lit" :instance i :do (aget i "type"))
(aclosure ac :attribute "default type by value" :type "slice lit" :instance i :do (aget i "type"))
(aclosure ac :attribute "default type by value" :type "struct lit" :instance i :do (aget i "type"))
(aclosure ac :attribute "default type by value" :type "map lit" :instance i :do (aget i "type"))

(aclosure ac :attribute "default type by value" :type "function lit" :instance i :stage nil :do
    (update-push-aclosure ac :stage "exit function lit")
    (clear-update-eval-aclosure ac :instance (aget i "signature"))
)
(aclosure ac :attribute "default type by value" :type "function lit" :instance i :stage "exit function lit"
    :value tsgn :do (mo "function type" :at "signature" tsgn)
)

(aclosure ac :attribute "default type by value" :type "signature" :instance i :stage nil 
    :ap i "parameters" psraw :p (reverse psraw) rps :p nil ps 
    :ap i "result" rraw :p (reverse rraw) rr :p nil r 
    :ap i "variadic parameter" vpraw :p nil vp :do
    (dolist (item rps) (push (aget item "type") ps))  ; Собираем только типы параметров
    (when (and rr (is-instance (car rr) "parameter decl"))
        (dolist (item rr) (push (aget item "type") r))  ; Обрабатываем результат фукнции
    )
    (when vpraw (setq vp (aget vpraw "type")))  ; Обрабатываем вариационный параметр
    (mo "type signature" :av "types" ps :av "variadic type" vp :av "result" r)
)

(aclosure ac :attribute "default type by value" :type "function lit" :instance i :do (aget i "type"))


;;; default value by type
(aclosure ac :attribute "default value by type" :type "boolean type" i :do nil)
(aclosure ac :attribute "default value by type" :type "int type" i :do 0)
(aclosure ac :attribute "default value by type" :type "float type" i :do 0.0)
(aclosure ac :attribute "default value by type" :type "complex type" i :do (complex 0 0))
(aclosure ac :attribute "default value by type" :type "rune type" i :do 0)
(aclosure ac :attribute "default value by type" :type "string type" i :do "")

(aclosure ac :attribute "default value by type" :type "array type" i :stage nil :do 
    (update-push-aclosure ac :stage "exit array type")
    (clear-update-eval-aclosure ac :instace (aget i "element type"))  ; Вычисляем значение по умолчанию для элементов этого массива
)
(aclosure ac :attribute "default value by type" :type "array type" i :stage "exit array type" :value tp :do 
    (make-list (aget i "len") :initial-element tp)
)

(aclosure ac :attribute "default value by type" :type "slice type" i :do nil)

(aclosure ac :attribute "default value by type" :type "struct type" i :stage nil 
    :ap i "fields" fs :p (attributes fs) ns :p (co :amap "identifier" "Go value") fv :v (> (length ns) 0) :do 
    (update-push-aclosure ac :stage "adding default value" :av "current" 0 :av "field values" fv)
    (clear-update-eval-aclosure ac :instance (aget fs (car ns)))
)
(aclosure ac :attribute "default value by type" :type "struct type" i :stage "adding default value" 
    :ap i "fields" fs :p (attributes fs) ns :ap ac "current" p :ap ac "field values" fv :value default :do 
    (aset fv (nth p ns) default)  ; Добавляем значение нового поля
    (update-eval-aclosure ac :av "field values" fv :av "current" (+ p 1))  ; Шаг итерации
    (match :v (< (+ p 1) (length ns)) T 
        :do (clear-update-eval-aclosure ac :instance (aget fs (nth (+ p 1) ns)))  ; Вычисляем значение по умолчанию для следующего поля
        :exit (mo "struct lit" :av "type" i :av "value" fv)  ; Если все поля готовы, то вернуть
    )
)

(aclosure ac :attribute "default value by type" :type "pointer type" i :do nil)
(aclosure ac :attribute "default value by type" :type "function type" i :do nil)
(aclosure ac :attribute "default value by type" :type "interface type" i :do nil)
(aclosure ac :attribute "default value by type" :type "map type" i :do nil)
(aclosure ac :attribute "default value by type" :type "channel type" i :do nil)


;;; Enviroment and Agents
(mot "env" 
    :at "agents" (listt "agent")
)
(mot "agent"
    :at "location" (cot :amap "identifier" "location")  ; The relation of names to their memory locations
    :at "type" (cot :amap "type name" "type")      ; Types created in the program
    :at "value" "Go value"                              ; The last value calculated by the agent
)


;;; Go values
(aclosure ac :attribute "opsem::rvalue" :type "Go value" i :do i)

(aclosure ac :attribute "opsem::rvalue" :type "identifier" i :agent a :do (aget (aget a "location" i) "value"))
(aclosure ac :attribute "opsem::lvalue" :type "identifier" i :agent a :do (aget a "location" i))


;;; Blocks
(aclosure ac :attribute "opsem" :type "block" i :stage nil
    :ap i "statements" sts :ap i "variable location" vl :p (attributes vl) ns :do
    (update-push-aclosure ac :stage "variable handling" :av "current" 0 :av "bound" (length ns) :av "variable location" vl :av "names" ns)
    (clear-update-eval-aclosure ac :stage "evaluating statement" :av "current" 0 :av "bound" (length sts) :av "statements" sts)
)
(aclosure ac :attribute "opsem" :type "block" i :stage "evaluating statement"
    :ap ac "current" p :ap ac "bound" n :ap ac "statements" sts :v (< p n) T :do
    (update-push-aclosure ac "current" (+ p 1))
    (clear-update-eval-aclosure ac :instance (nth p sts))
)
(aclosure ac :attribute "opsem" :type "block" i :stage "variable handling" :agent a
    :ap ac "current" p :ap ac "bound" n :ap ac "variable location" vl :ap "names" ns :v (< p n) T :do 
    (aset a "location" (nth p ns) (nth p vl))  ; Возвращаем прежнее значение переменной
    (clear-update-eval-aclosure ac "current" (+ p 1))
)


;;; Declarations
(aclosure ac :attribute "opsem" :type "type decl" :instance i :agent a :do (aset a "type" (aget i "name") (aget i "type")))

(aclosure ac :attribute "opsem" :type "const decl block" :instance i :stage nil :do 
    (update-push-aclosure ac :stage "exit const decl block")
    (clear-update-eval-aclosure ac :stage "declarating" :av "current" 0)
)
(aclosure ac :attribute "opsem" :type "const decl block" :instance i :stage "declarating" 
    :ap ac "current" k :ap i "declarations" ds :p (length ds) n :v (< n k) T :agent a :do 
    (aset a "location" "iota" (mo "location" :av "type" "uint" :av "value" k))
    (update-push-aclosure ac :av "current" (+ k 1))
    (clear-update-eval-aclosure ac :instance (nth k ds))
)
(aclosure ac :attribute "opsem" :type "const decl block" :instance i :stage "exit const decl block" :do (aset "iota" nil))  ; optional

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
