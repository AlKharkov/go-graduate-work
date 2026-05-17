;;; Type substitution - подставляет типы к каждой переменной, константе, параметру функции и т.п.
; Проходит список с конца, запоминая последнее не-nil значение. Если встречает nil, то заменяет его на запомненное.
(aclosure ac :attribute "type substitution" :type (listt "type") :instance i :do ; !!
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

(typedef "bool" (enumt "true" "false"))
(mot "result" :at "value" (listt "bool"))

(aclosure ac :attribute "type substitution" :type "result" :instance i :stage nil 
    (aset i "value" (list))
)



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



;;; ================================================
;;; Declarations
;;; ================================================

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




;;;;;;; Может пригодится для function call

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










(aclosure ac :attribute "opsem::rvalue" :type "typed primitive" :instance i 
    :stage "converting numbers to type" :ap i "value" raw :ap i "type" tp :do 
    (match :v (is-instance tp "int type") T :ap tp "bit size" bs :p (mod raw (ash 1 bs))  ; если примитив - число
    :do (mo "typed primitive" :av "type" tp :av "value" 
            (nmatch :v (is-instance tp "unsigned int type") T :exit v  ; если беззнаковое
                    :v (< v (ash 1 (1- bs))) T :exit v  ; если беззнаковое не выходило за границы знаковых
                    :do (- v (ash 1 (1- bs)))))  ; иначе
    :exit i)  ; если примитив не число
)






; Копирует список ячеек, не заходит в глубину
(defun copy-cells (lst)
    (let ((r nil)) (dolist (c (reverse lst) r) 
        (setq r (cons (mo "cell" :av "type" (aget c "type") :av "value" (aget c "value")) r))))
)