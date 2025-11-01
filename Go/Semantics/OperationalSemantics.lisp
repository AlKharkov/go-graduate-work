#|
	Operational semantics for the Go language

    Last edit: 01/11/2025
|#


;;; Enviroment and Agents
(mot "env" 
    :at "agents" (listt "agent")
    :at "init target construct" (uniont "expression" "statement" "external declaration" "translation unit")
)
(mot "agent"
    :at "variable location" (cot :amap "variable" "location")
    :at "location value" (cot :amap "location" "Go value")
    :at "location type" (cot :amap "location" "type")
    :at "function signature" (cot :amap "location" "signature")
    :at "function body" (cot :amap "location" "block")
)


;;; Go values
(aclosure "opsem" "Go value" i ac i)


;;; Variables
(aclosure "opsem::rvalue" "variable" i ac (match :ap ac "agent" a :do (aget a "location value" (aget a "variable location" i))))
(aclosure "opsem::lvalue" "variable" i ac (aget ac "agent" "variable location" i))


;;; Blocks
(aclosure "opsem" "block" i ac
    (match :av ac "stage" nil :ap i "statements" sts :do
        (update-push-aclosure ac "stage" "exit block")
        (clear-update-eval-aclosure ac :av "stage" "iteration" :av "current" 0 :av "bound" (length sts) :av "statements" sts)  ; u-p-a -> c-u-e-a
    )
    (match :av ac "stage" "iteration" :ap ac "current" p :ap ac "bound" n :ap ac "statements" sts :v (< p n) T :do  ; В оригинале нет "ac" после :ap
        (update-push-aclosure ac "current" (+ p 1))
        (clear-update-eval-aclosure ac "instance" (nth p sts))
    )
    (match :av ac "stage" "exit block" :av i "variables" vs :do
        (clear-update-eval-aclosure ac :av "stage" "variable handling" :av "variables" vs)
    )
    (match :av ac "stage" "variable handling" :ap i "variables" vs :v (not (empty vs)) T :p (nth 0 vs) v :p (aget i "variable location" v) vl :ap ac "agent" a :do
        (update-push-aclosure ac "variables" (cdr vs))
        ; TODO
        ; Удалить a["variable location"][v]
        ; Если не nil, то:
        ;   Создать a["variable location"].add(v, vl)
    )
)


;;; Declarations
;TODO


;;; Expressions
;; Operands
(aclosure "opsem::lvalue" "(expression)" i ac (clear-update-eval-aclosure ac "instance" (aget i "expression")))
(aclosure "opsem::rvalue" "(expression)" i ac (clear-update-eval-aclosure ac "instance" (aget i "expression")))
(aclosure "opsem::rvalue" "composite literals" ...)  ; TODO
(aclosure "opsem::rvalue" "function literal" i ac
    ; Создать объект function definition = fd
    ; TODO
)
(aclosure "opsem::rvalue" "operand" i ac i)
(aclosure "opsem::rvalue" "conversion" i ac ...)  ; TODO
(aclosure "opsem::rvalue" "method expression" i ac ...)  ; TODO
;(mot "struct" :at "fields" (listt "field valued"))              ; Куда это?
;(mot "field valued" :at "name" "identifier" :at "value" "Go value")  ; Определение экземпляра структурного объекта
(aclosure "opsem::lvalue" "selector expression" i ac
    (match :av ac "stage" nil :do
        (update-push-aclosure ac "stage" "access")
        (clear-update-eval-aclosure ac "instance" (aget i "expression"))
    )
    (match :av ac "stage" "access" :ap ac "agent" a :ap a "value" e :ap i "selector" name :do
        (update-push-aclosure )
        (clear-update-eval-aclosure ac :ap )
    )
)


