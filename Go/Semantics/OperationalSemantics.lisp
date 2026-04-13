#|
	Operational semantics for the Go language

    Last edit: 10/04/2026
|#


;;; ================================================
;;; Enviroment and Agents
;;; ================================================

(mot "env"  :at "agents" (listt "agent"))
(mot "agent"
    :at "constant value" (mot :amap "constant name" "Go value")
    :at "variable cell"  (mot :amap "variable name" "cell")           ; The relation of names to their memory locations
    :at "function value" (mot :amap "function name" "function value")
    :at "method value"   (mot :amap "type name" (mot :amap "method name" "method value"))
    :at "type"           (mot :amap "type name" "type")               ; Types created in the program
    :at "value"          "Go value")                                  ; The last value calculated by the agent


;;; ================================================
;;; Values and names
;;; ================================================

(aclosure ac :attribute "opsem::rvalue" :type "Go value" :instance i :do i)


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
    :ap i "elements" es :ap i "type" at :ap at "elem type" et 
    :ap (mo "pointer type" :av "type" et) ct :value v :do 
    (match :v (null es) T :do (mo "array value" :av "type" at :av "elements" nil) 
    :exit (update-push-aclosure ac :stage "evaluating" :av "left" es 
              :av "array" (let ((c nil)) (dotimes (k (aget at "len") c) 
              (setf c (cons (mo "cell" :av "value" v :av "type" ct) c))))) ; массив из "len" ячеек памяти
          (clear-update-eval-aclosure ac :instance (aget (car es) "value")))
)
; Изменяет значение очередного элемента массива.
; Если все значения вычислены, то создаёт и возвращает значение массива. Иначе отправляет вычислять далее.
(aclosure ac :attribute "opsem::rvalue" :type "array lit" :instance i :stage "evaluating" 
    :ap ac "left" left :ap ac "array" arr :value v :ap (car left) "index" k :do 
    (let ((c arr)) (dotimes (j k (setf (car c) "value" v)) (setf c (cdr c))))  ; изменяем k-й элемент списка
    (match :v (null (cdr left)) T :do (mo "array value" :av "type" (aget i "type") :av "elements" arr)
    :exit (update-push-aclosure ac :av "left" (cdr left) :av "array" arr)
          (clear-update-eval-aclosure ac :instance (aget (car (cdr left)) "value")))
)

;; slice lit
; Отправляет вычислять значение по умолчанию для элементов среза.
(aclosure ac :attribute "opsem::rvalue" :type "slice lit" :instance i :stage nil :do 
    (update-push-aclosure ac :stage "build value")
    (update-push-aclosure ac :stage "fill defaults")
    (clear-update-eval-aclosure ac :attribute "default value by type" :instance (aget i "type" "elem type"))
)
; По максимальному индексу создаёт массив. Отправляет вычислять явно заданные значения.
; Возвращает список всех вычисленных значений.
(aclosure ac :attribute "opsem::rvalue" :type "slice lit" :instance i :stage "fill defaults" 
    :value v :ap i "elements" es :p -1 m :ap (mo "pointer type" 
    :av "type" (mo "pointer type" :av "type" (aget i "type" "elem type"))) ct :do 
    (dolist (e es) (let ((k (aget e "index"))) (if (> k m) (setf m k))))
    (match :v (null es) T :do nil
    :exit (update-push-aclosure ac :stage "evaluating" :av "left" es :av "array" 
        (let ((c nil)) (dotimes (k (1+ m) c) (setf c (cons (mo "cell" :av "value" v :av "type" ct) c)))))
        (clear-update-eval-aclosure ac :instance (aget (car es) "value")))
)
; Изменяет значение очередного элемента среза.
; Если все значения вычислены, то возвращает их в правильном порядке. Иначе отправляет вычислять далее.
(aclosure ac :attribute "opsem::rvalue" :type "slice lit" :instance i :stage "evaluating" 
    :ap ac "left" left :ap ac "array" arr :value v :p (aget (car left) "index") k :do 
    (let ((c arr)) (dotimes (j k (setf (car c) "value" v)) (setf c (cdr c))))
    (match :v (null left) T :do (reverse arr) 
    :exit (update-push-aclosure ac :av "left" (cdr left) :av "array" arr)
          (clear-update-eval-aclosure ac :instance (aget (car (cdr left)) "value")))
)
; Создаёт и возвращает значение среза.
(aclosure ac :attribute "opsem::rvalue" :type "slice lit" :instance i :stage "build value" 
    :value arr :ap i "type" stp :ap stp "elem type" etp :p (length arr) n :do 
    (mo "slice value" 
        :av "type" (aget i "type")
        :av "array" (mo "array value" :av "type" (mo "array type" :av "elem type" etp :av "len" n) 
                                      :av "elements" arr)
        :av "offset" 0 
        :av "length" n
        :av "capacity" n)
)

;; struct lit
; Отправляет вычислять значения полей по умолчанию. Отправляет вычислять явно указанные значения полей.
(aclosure ac :attribute "opsem::rvalue" :type "struct lit" :instance i :stage nil 
    :p (aget i "type" "fields") tfs :p (attributes tfs) tns :do 
    (update-push-aclosure ac :stage "eval field values")
    (match :v (null ns) T :do nil 
    :exit (update-push-aclosure ac :stage "filling defaults" 
                                   :av "type field names" tns 
                                   :av "struct value" (mo :amap "field name" "cell"))
          (clear-update-eval-aclosure ac :attribute "default value by type" 
                                         :instance (aget tfs (car tns))))
)
; Если всем полям установлены значения, то возвращает список из них. Иначе отправляет вычислять значение очередного поля.
(aclosure ac :attribute "opsem::rvalue" :type "struct lit" :instance i :stage "filling defaults" 
    :ap ac "type field names" tns :ap ac "struct value" sv :value dv 
    :p (mo "pointer type" :av "type" (mo "pointer type" :av "type" (aget i "type" "fields" (car tns)))) ct :do 
    (aset sv (car tns) (mo "cell" :av "value" dv :av "type" ct))  ; устанавливает значение по умолчанию очередного поля структуры
    (match :v (null tns) T :do sv 
    :exit (update-push-aclosure ac :av "type field names" (cdr tns) :av "struct value" sv)
          (clear-update-eval-aclosure ac :attribute "default value by type" 
                                         :instance (aget (aget i "type" "fields") (car (cdr tns)))))
)
; Если значение никакого поля явно не задано, то возвращает пустой список.
; Иначе отправляет вычислять вычислять значения явно заданных полей структуры.
(aclosure ac :attribute "opsem::rvalue" :type "struct lit" :instance i :stage "eval field values" 
    :value sv :ap i "fields" fs :p (attributes fs) ns :do 
    (match :v (null ns) T :do nil 
    :exit (update-push-aclosure ac :stage "evaluating" :av "names" ns :av "struct value" sv)
          (clear-update-eval-aclosure ac :instance (aget fs (car ns))))
)
; Устанавливает значение очередного явно заданного поля в значение структуры.
; Если все значения полей вычислены, то возвращает их список. Иначе отправляет вычислять значение очередного поля.
(aclosure ac :attribute "opsem::rvalue" :type "struct lit" :instance i :stage "evaluating" 
    :ap ac "names" ns :ap ac "struct value" sv :ap i "fields" fs :value v :do 
    (aset sv (car ns) "value" v)
    (match :v (null (cdr ns)) T :do sv 
    :exit (update-push-aclosure ac :av "names" (cdr ns) :av "struct value" sv)
          (clear-update-eval-aclosure ac :instance (aget fs (car (cdr ns)))))
)
; Создаёт и возвращает значение структуры.
(aclosure ac :attribute "opsem::rvalue" :type "struct lit" :instance i :stage "build value" 
    :value sv :do (mo "struct value" :av "type" (aget i "type") :av "fields" sv)
)

;; map lit
; Отправляет вычислять записи карты (т.е. пары ключ-значение).
(aclosure ac :attribute "opsem::rvalue" :type "map lit" :instance i :stage nil 
    :ap i "elements" es :do 
    (update-push-aclosure ac :stage "build value")
    (match :v (null es) T :do nil 
    :exit (update-push-aclosure ac :stage "evaluating" 
                                   :av "entries" (mo :amap "Go value" "cell") 
                                   :ap "elements" (cdr es))
          (clear-update-eval-aclosure ac :instance (car es) :av "elem type" (aget i "type" "elem type")))
)
; Добавляет вычисленную запись. Если все записи вычислены, то возвращает их список. Иначе отправляет вычислять далее.
(aclosure ac :attribute "opsem::rvalue" :type "map lit" :instance i :stage "evaluating" 
    :ap ac "entries" ent :ap ac "elements" es :value ke :do 
    (aset ent (aget ke "key") (aget ke "value"))
    (match :v (null es) T :do ent 
    :exit (update-push-aclosure ac :av "entries" ent :av "elements" (cdr es))
          (update-push-aclosure ac :instance (car es)))
          (clear-update-eval-aclosure ac :instance (aget (car es) "key") 
                                         :av "elem type" (aget i "type" "elem type"))
)
; Создаёт и возвращает значение карты.
(aclosure ac :attribute "opsem::rvalue" :type "map lit" :instance i :stage "build value" 
    :value ent :do (mo "map value" :av "type" (aget i "type") :av "entries" ent)
)
; Отправляет вычислять значение записи.
(aclosure ac :attribute "opsem::rvalue" :type "keyed elem" :instance i :stage nil 
    :value k :do (update-push-aclosure ac :stage "eval value" :av "key" k)
                 (clear-update-eval-aclosure ac :instance (aget i "value"))
)
; Создаёт и возвращает запись карты.
(aclosure ac :attribute "opsem::rvalue" :type "keyed elem" :instance i :stage "eval value" 
    :ap ac "key" k :ap ac "elem type" et :value v :do (mo "keyed value" :av "key" k :av "value" 
        (mo "cell" :av "value" v :av "type" (mo "pointer type" :av "type" et)))
)

;; function lit
; Создаёт и возвращает значение функции.
(aclosure ac :attribute "opsem::rvalue" :type "function lit" :instance i 
    :agent a :p (aget i "body" "all variables") ns :p nil c :do 
    (dolist (item ns) (setf c (aset c (aget a "variable cell" item))))  ; сохраняет ячейки памяти всех переменных до блока
    (mo "function value" :av "type"      (aget i "type")
                         :av "signature" (aget i "signature")
                         :av "body"      (aget i "body")
                         :av "closure"   c)
)


;; method lit
; Создаёт и возвращает значение метода.
(aclosure ac :attribute "opsem::rvalue" :type "method lit" :instance i 
    :agent a :p (aget i "body" "all variables") ns :p nil c :do 
    (dolist (item ns) (setf c (aset c (aget a "variable cell" item))))  ; сохраняет ячейки памяти всех переменных до блока
    (mo "method value"  :av "type"      (aget i "type")
                        :av "signature" (aget i "signature")
                        :av "body"      (aget i "body")
                        :av "closure"   c)
)


;;; ================================================
;;; Declarations
;;; ================================================

;; type decl
(aclosure ac :attribute "opsem" :type "type decl" :instance i :agent a :do 
    (aset a "type" (aget i "name") (aget i "type"))
)

;; var decl
; Если задаются без значений, то вычилсяем значения по типам переменеых.
; Иначе все переменные задаются с явно указанными значениями.
(aclosure ac :attribute "opsem" :type "var decl" :instance i :stage nil 
    :ap i "names" ns :ap i "values" vs :ap i "types" ts :do 
    (match :v (null vs) T 
    :do (update-push-aclosure ac :stage "declarating defaults" :av "names" ns :av "types" (cdr ts))
        (clear-update-eval-aclosure ac :attribute "default value by type" :instance (car ts))
    :exit (update-push-aclosure ac :stage "evaluating values" 
        :av "names" ns :av "types" ts :av "values" (cdr vs))
        (clear-update-eval-aclosure ac :instance (car vs))
    )
)
; Декларируем очередную переменную по значению по умолчанию соответсвующего типа.
(aclosure ac :attribute "opsem" :type "var decl" :instance i :stage "declarating defaults" 
    :ap ac "names" ns :ap ac "types" ts :value v :agent a :do 
    (aset a "variable cell" (car ns) (mo "cell" :av "value" v 
        :av "type" (mo "pointer type" :av "type" (car ts))))
    (match :v (null ts) T 
    :exit (update-push-aclosure ac :av "names" (cdr ns) :av "types" (cdr ts))
          (clear-update-eval-aclosure ac :attribute "default value by type" :instance (car ts)))
)
; Декларируем очередную переменную по явно заданному значению.
(aclosure ac :attribute "opsem" :type "var decl" :instance i :stage "evaluating values" 
    :ap ac "names" ns :ap ac "values" vs :ap ac "types" ts :value v :agent a :do 
    (aset a "variable cell" (car ns) (mo "cell" :av "value" v :av "type" (car ts)))
    (match :v (null vs) T 
    :exit (update-push-aclosure ac :av "names" (cdr ns) :av "types" (cdr ts) :av "values" (cdr vs))
          (clear-update-eval-aclosure ac :instance (car vs)))
)

;; function decl
(aclosure ac :attribute "opsem" :type "function decl" :instance i :stage nil :do 
    (update-push-aclosure ac :stage "decl")
    (clear-update-eval-aclosure ac :instance (aget i "value"))
)
(aclosure ac :attribute "opsem" :type "function decl" :instance i :stage "decl" 
    :value v :agent a :do (aset a "function value" (aget i "name") v)
)

;; method decl
(aclosure ac :attribute "opsem" :type "method decl" :instance i :stage nil :do 
    (update-push-aclosure ac :stage "decl")
    (clear-update-eval-aclosure ac :instance (aget i "value"))
)
(aclosure ac :attribute "opsem" :type "method decl" :instance i :stage "decl" 
    :value v :agent a :do (aset a "method value" (aget i "value" "type" "receiver type") (aget i "name") v)
)


;;; ================================================
;;; Blocks
;;; ================================================

; Сохраняет ячейки всех переменных, встречающихся в этом блоке. При декларации будут созданы новые ячейки.
(aclosure ac :attribute "opsem" :type "block" :instance i :stage nil 
    :ap i "statements" sts :ap i "decl variables" avs :p nil dv :agent a :do 
    (aset i "variable cells" (dolist 
        (item avs (reverse dv)) 
        (setf dv (cons (aget a "variable cell" item) dv))))
    (update-push-aclosure ac :stage "variable back")
    (clear-update-eval-aclosure ac :stage "evaluating statement" :av "statements" sts)
)
; Вычисляет очередной оператор блока (очередную инструкцию блока).
(aclosure ac :attribute "opsem" :type "block" :instance i :stage "evaluating statement" 
    :ap ac "statements" sts :v (null sts) nil :do 
    (update-push-aclosure ac :av "statements" (cdr sts) :av "block" i)
    (clear-update-eval-aclosure ac :instance (car sts))
)
; Восстанавливает старые ячейки памяти декларированным в блоке (важны только затенённые) переменным.
(aclosure ac :attribute "opsem" :type "block" :instance i :stage "variable back" :do 
    (dolist (item (aget i "decl variables")) (aset a "variable cell" item (aget item "variable cells")))
)


;;; ================================================
;;; Expressions
;;; ================================================

;; variable ref
(aclosure ac :attribute "opsem::lvalue" :type "variable ref" :instance i :agent a :do 
    (aget a "variable cell" i)
)
(aclosure ac :attribute "opsem::rvalue" :type "variable ref" :instance i :agent a :do 
    (aget (aget a "variable cell" i) "value")
)

;; parenthized expression
(aclosure ac :attribute "opsem::rvalue" :type "(1)" :instance i :do 
    (clear-update-eval-aclosure ac :instance (aget i 1))
)

;; conversion
(aclosure ac :attribute "opsem::rvalue" :type "conversion" :instance i :stage nil :do 
    (update-push-aclosure ac :stage "conversion")
    (clear-update-eval-aclosure ac :instance (aget i "value"))
)
(aclosure ac :attribute "opsem::rvalue" :type "conversion" :instance i :stage "conversion" 
    :value v :do ; To be continued
)

;; method expression
(aclosure ac :attribute "opsem::rvalue" :type "method expr" :instance i 
    :agent a :p (aget a "method value" (aget i "receiver type") (aget i "name")) mv 
    :ap mv "type" mt :ap mv "signature" ms :do 
    (mo "function value" 
        :av "type" (mo "function type" 
            :av "param types"   (cons (aget mt "receiver type") (aget mt "param types"))
            :av "variadic type" (aget mt "variadic type")
            :av "result type"   (aget mt "result types"))
        :av "signature" (mo "function signature" 
            :av "parameters"     (cons (aget ms "receiver") (aget ms "parameters"))
            :av "variadic param" (aget ms "variadic param")
            :av "result"         (aget ms "result"))
        :av "body" (aget mv "body")
        :av "closure" (aget mv "closure"))
)

;; selector expression
; Если слева от точки стоит имя пользовательского типа (в том числе интерфейса), то вычислять ничего не нужно
(aclosure ac :attribute "opsem::rvalue" :type "selector expr" :instance i :stage nil
    :ap i "receiver" r :do 
    (update-push-aclosure ac :stage "return value")
    (match :v (and (is-instance r "identifier") (aget a "type" r)) T 
    :do   (aget a "method value" r (aget i "name"))
    :exit (clear-update-eval-aclosure ac :instance (aget i "receiver")))
)
; Иначе слева стоит структура, или указатель на стркутуру, который сначала нужно разыменовать.
(aclosure ac :attribute "opsem::rvalue" :type "selector expr" :instance i :stage "return value" 
    :value r :ap r "type" tr :ap i "name" n :do 
    (nmatch :v tr "struct type"  :exit (aget r "fields" n "value") 
            :v tr "pointer type" :exit (aget r "target" "value" "fields" n "value"))
)

; В lvalue позиции может быть только структура (или указатель на неё)
(aclosure ac :attribute "opsem::lvalue" :type "selector expr" :instance i :stage nil :do 
    (update-push-aclosure ac :stage "return value")
    (clear-update-eval-aclosure ac :instance (aget i "receiver"))
)
(aclosure ac :attribute "opsem::lvalue" :type "selector expr" :instance i :stage "return value" 
    :value r :ap i "name" n :ap r "type" tr :do 
    (nmatch :v tr "struct type" :exit  (aget r "fields" n)
            :v tr "pointer type" :exit (aget r "target" "value" "fields" n))
)

;; index expression
; Вычисляет индексированное хранилище (массив, срез, карта или строка)
(aclosure ac :attribute "opsem::rvalue" :type "index expr" :instance i :stage nil :do 
    (update-push-aclosure ac :stage "eval index")
    (clear-update-eval-aclosure ac :instance (aget i "indexable"))
)
; Вычисляет индекс, по которому нужно будет взять элемент
(aclosure ac :attribute "opsem::rvalue" :type "index expr" :instance i :stage "eval index" 
    :value indl :do 
    (update-push-aclosure ac :stage "return value" :av "indexable" indl)
    (clear-update-eval-aclosure ac :instance (aget i "index"))
)
; Возвращает взятый по индексу элемент
(aclosure ac :attribute "opsem::rvalue" :type "index expr" :instance i :stage "return value" 
    :value index :ap ac "indexable" indl :ap indl "type" it :do 
    (nmatch :v it "array type"  :exit (aget (nth index (aget indl "elements")) "value")
            :v it "slice type"  :exit (aget (nth (+ offset index) (aget indl "array" "elements")) "value")
            :v it "map type"    :exit (aget (aget indl "entries" index) "value")
            :v it "string type" :exit (char (aget indl "value") index))
)

; Для lvalue всё вычисляется абсолютно так же
(aclosure ac :attribute "opsem::lvalue" :type "indexable expr" :instance i :stage nil :do 
    (update-push-aclosure ac :stage "eval index")
    (clear-update-eval-aclosure ac :instance (aget i "indexable"))
)
(aclosure ac :attribute "opsem::lvalue" :type "index expr" :instance i :stage "eval index" 
    :value indl :do 
    (update-push-aclosure ac :stage "return value" :av "indexable" indl)
    (clear-update-eval-aclosure ac :instance (aget i "index"))
)
; Строки являются неизменяемыми
(aclosure ac :attribute "opsem::lvalue" :type "index expr" :instance i :stage "return value" 
    :value index :ap ac "indexable" indl :ap indl "type" it :do 
    (nmatch :v it "array type" :exit (nth index (aget indl "elements")) 
            :v it "slice type" :exit (nth (+ offset index) (aget indl "array" "elements"))
            :v it "map type"   :exit (aget indl "entries" index))
)



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
