#|
	Operational semantics for the Go language

    Last edit: 31/10/2025
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
(aclosure "opsem" (uniont "constant" "location") i ac i)
(aclosure "opsem" "function definition" i ac 
    (match :av ac "stage" nil ...)  ; Сохранить все переменные из body и parameters - "variable string"
    (match :av ac "stage" "body" :do
        (update-push-aclosure ac "stage" "body")
        (clear-update-eval-aclosure ac "instance" (aget i "signature"))
        ; Тут нужно добавить в агента вычисленную сигнатуру функции
        ;(aset (aget ac "agent") "function signature" (clear-update-eval-aclosure ac "instance" (aget i "signature")))
    )
    (match :av ac "stage" "body" :do
        (update-push-aclosure ac "stage" "exit function")
        (clear-update-eval-aclosure ac "instance" (aget i "body"))
        ; Тут нужно добавить в агента вычисленное body функции
    )
    (match :av ac "stage" "exit function definition" ...)  ; 1) Вернуть старые значения переменным из body и parameters. 2) Вернуть функцию
)
; Как мне вернуть сигнатуру?
(aclosure "opsem" "signature" i ac
    (match :av ac "stage" nil :do
        (update-push-aclosure ac "stage" "result")
        (clear-update-eval-aclosure ac "instance" (aget i "parameters"))
    )
    (match :av ac "stage" "result" :do
        (update-push-aclosure ac "stage" "exit signature")
        (clear-update-eval-aclosure ac "instance" (aget i "result"))
    )
)
; Как вернуть parameters?
(aclosure "opsem" "parameters" i ac
    (match :av ac "stage" nil ...)
    (match :av ac "stage" "declarations" :ap i "declarations" ds :do
        (update-push-aclosure ac "stage" "exit parameters")
        (clear-update-eval-aclosure ac :av "stage" "iteration" :av "current" 0 :av "bound" (length ds) :av "declarations" ds)
    )
    (match :av ac "stage" "iteration" :ap ac "current" p :ap ac "bound" n :ap ac "declarations" ds :v (< p n) T :do
        (update-push-aclosure ac "current" (+ p 1))
        (clear-eval-update-aclosure ac "instance" (nth p ds))
    )
)
;(typedef "function result" (uniont "parameters" "type"))  ; Значит можно ничего не писать для function result?
(aclosure "opsem" "parameter decl" i ac
    (match :av ac "stage" nil ...)
    (match :av ac "stage" "names" :ap i "names" ids :do
        (update-push-aclosure ac "stage" "exit parameter decl")
        (clear-update-eval-aclosure ac :av "stage" "iteration" :av "current" 0 :av "bound" (length ids) :av "names" ids)
    )
    (match :av ac "stage" "iteration" :ap ac "current" p :ap ac "bound" n :ap ac "names" ids :v (< p n) T :do
        (update-push-aclosure ac "current" (+ p 1))
        (clear-update-eval-aclosure ac "instance" (nth p ids))
    )
)


;;; Blocks
(aclosure "opsem" "block" i ac
    (match :av ac "stage" nil ...)
    (match :av ac "stage" "statements" :ap i "statements" sts :do
        (update-push-aclosure ac "stage" "exit block")
        (clear-update-eval-aclosure ac :av "stage" "iteration" :av "current" 0 :av "bound" (length sts) :av "statements" sts)  ; u-p-a -> c-u-e-a
    )
    (match :av ac "stage" "iteration" :ap ac "current" p :ap ac "bound" n :ap ac "statements" sts :v (< p n) T :do  ; В оригинале нет "ac" после :ap
        (update-push-aclosure ac "current" (+ p 1))
        (clear-update-eval-aclosure ac "instance" (nth p sts))
    )
    (match :av ac "stage" "exit block" :av i "variables" vs :do
        (update-push-aclosure ac :av "stage" "variable handling" :av "variables" vs)
    )
    (match :av ac "stage" "variable handling" :ap ac "variables" vs :v (not (empty vs)) T :do
        (update-push-aclosure ac :av "variables" (cdr vs))  ; Это список без первого элемента
        ...
    )
)


;;; Variables
; Разве не нужно для переменных ::rvalue ::lvalue?
(aclosure "opsem::rvalue" "variable" i ac (match :ap ac "agent" a :do (aget a "location value" (aget a "variable location" i))))
(aclosure "opsem::lvalue" "variable" i ac (aget ac "agent" "variable location" i))


;;; Types
(aclosure "opsem" "base type" i ac i)
(aclosure "opsem")

