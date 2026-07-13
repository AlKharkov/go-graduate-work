#|
	Operational semantics for the Go language

    Last edit: 13/07/2026
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

(aspect "opsem::rvalue" :context ac :type "Go value" :instance i :do i)


;;; ================================================
;;; Literals
;;; ================================================

;; array lit
; Отправляет вычислять значение по умолчанию для элементов массива.
(aspect "opsem::rvalue" :context ac :type "array lit" :instance i :stage nil :do 
    (update-push-acontext ac :stage "fill defaults")
    (clear-update-eval-acontext ac :aspect "default value by type" :instance (aget i "type" "elem type"))
)
; Заполняет массив значениями по умолчанию. Отправляет вычислять явно заданные значения.
(aspect "opsem::rvalue" :context ac :type "array lit" :instance i :stage "fill defaults" 
    :ap i "elements" es :ap i "type" at :ap at "elem type" et 
    :p (mo "pointer type" :av "type" et) ct :value v :do 
    (match :v (null es) T :do (mo "array value" :av "type" at :av "elements" nil) 
    :exit (update-push-acontext ac :stage "evaluating" :av "left" es 
              :av "array" (let ((c nil)) (dotimes (k (aget at "len") c) 
              (setf c (cons (mo "cell" :av "value" v :av "type" ct) c))))) ; массив из "len" ячеек памяти
          (clear-update-eval-acontext ac :instance (aget (car es) "value")))
)
; Изменяет значение очередного элемента массива.
; Если все значения вычислены, то создаёт и возвращает значение массива. Иначе отправляет вычислять далее.
(aspect "opsem::rvalue" :context ac :type "array lit" :instance i :stage "evaluating" 
    :ap ac "left" left :ap ac "array" arr :value v :ap (car left) "index" k :do 
    (let ((c arr)) (dotimes (j k (setf (car c) "value" v)) (setf c (cdr c))))  ; изменяем k-й элемент списка
    (match :v (null (cdr left)) T :do (mo "array value" :av "type" (aget i "type") :av "elements" arr)
    :exit (update-push-acontext ac :av "left" (cdr left) :av "array" arr)
          (clear-update-eval-acontext ac :instance (aget (car (cdr left)) "value")))
)

;; slice lit
; Отправляет вычислять значение по умолчанию для элементов среза.
(aspect "opsem::rvalue" :context ac :type "slice lit" :instance i :stage nil :do 
    (update-push-acontext ac :stage "build value")
    (update-push-acontext ac :stage "fill defaults")
    (clear-update-eval-acontext ac :aspect "default value by type" :instance (aget i "type" "elem type"))
)
; По максимальному индексу создаёт массив. Отправляет вычислять явно заданные значения.
; Возвращает список всех вычисленных значений.
(aspect "opsem::rvalue" :context ac :type "slice lit" :instance i :stage "fill defaults" 
    :value v :ap i "elements" es :p -1 m :ap (mo "pointer type" 
    :av "type" (mo "pointer type" :av "type" (aget i "type" "elem type"))) ct :do 
    (dolist (e es) (let ((k (aget e "index"))) (if (> k m) (setf m k))))
    (match :v (null es) T :do nil
    :exit (update-push-acontext ac :stage "evaluating" :av "left" es :av "array" 
        (let ((a nil)) (dotimes (k (1+ m) a) (setf a (cons (mo "cell" :av "value" v :av "type" ct) a)))))
        (clear-update-eval-acontext ac :instance (aget (car es) "value")))
)
; Изменяет значение очередного элемента среза.
; Если все значения вычислены, то возвращает их в правильном порядке. Иначе отправляет вычислять далее.
(aspect "opsem::rvalue" :context ac :type "slice lit" :instance i :stage "evaluating" 
    :ap ac "left" left :ap ac "array" arr :value v :p (aget (car left) "index") k :do 
    (let ((c arr)) (dotimes (j k (setf (car c) "value" v)) (setf c (cdr c))))
    (match :v (null left) T :do (reverse arr) 
    :exit (update-push-acontext ac :av "left" (cdr left) :av "array" arr)
          (clear-update-eval-acontext ac :instance (aget (car (cdr left)) "value")))
)
; Создаёт и возвращает значение среза.
(aspect "opsem::rvalue" :context ac :type "slice lit" :instance i :stage "build value" 
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
(aspect "opsem::rvalue" :context ac :type "struct lit" :instance i :stage nil 
    :p (aget i "type" "fields") tfs :p (attributes tfs) tns :do 
    (update-push-acontext ac :stage "build value")
    (update-push-acontext ac :stage "eval field values")
    (match :v (null ns) T :do nil 
    :exit (update-push-acontext ac :stage "filling defaults" 
                                   :av "type field names" tns 
                                   :av "struct value" (mo :amap "field name" "cell"))
          (clear-update-eval-acontext ac :aspect "default value by type" 
                                         :instance (aget tfs (car tns))))
)
; Если всем полям установлены значения, то возвращает список из них. Иначе отправляет вычислять значение очередного поля.
(aspect "opsem::rvalue" :context ac :type "struct lit" :instance i :stage "filling defaults" 
    :ap ac "type field names" tns :ap ac "struct value" sv :value dv 
    :p (mo "pointer type" :av "type" (mo "pointer type" :av "type" (aget i "type" "fields" (car tns)))) ct :do 
    (aset sv (car tns) (mo "cell" :av "value" dv :av "type" ct))  ; устанавливает значение по умолчанию очередного поля структуры
    (match :v (null tns) T :do sv 
    :exit (update-push-acontext ac :av "type field names" (cdr tns) :av "struct value" sv)
          (clear-update-eval-acontext ac :aspect "default value by type" 
                                         :instance (aget (aget i "type" "fields") (car (cdr tns)))))
)
; Отправляет вычислять вычислять значения явно заданных полей структуры.
(aspect "opsem::rvalue" :context ac :type "struct lit" :instance i :stage "eval field values" 
    :value sv :ap i "fields" fs :p (attributes fs) ns :do 
    (match :v (null ns) T :do sv 
    :exit (update-push-acontext ac :stage "evaluating" :av "names" ns :av "struct value" sv)
          (clear-update-eval-acontext ac :instance (aget fs (car ns))))
)
; Устанавливает значение очередного явно заданного поля в значение структуры.
; Если все значения полей вычислены, то возвращает их список. Иначе отправляет вычислять значение очередного поля.
(aspect "opsem::rvalue" :context ac :type "struct lit" :instance i :stage "evaluating" 
    :ap ac "names" ns :ap ac "struct value" sv :ap i "fields" fs :value v :do 
    (aset sv (car ns) "value" v)
    (match :v (null (cdr ns)) T :do sv 
    :exit (update-push-acontext ac :av "names" (cdr ns) :av "struct value" sv)
          (clear-update-eval-acontext ac :instance (aget fs (car (cdr ns)))))
)
; Создаёт и возвращает значение структуры.
(aspect "opsem::rvalue" :context ac :type "struct lit" :instance i :stage "build value" 
    :value sv :do (mo "struct value" :av "type" (aget i "type") :av "fields" sv)
)

;; map lit
; Отправляет вычислять записи карты (т.е. пары ключ-значение).
(aspect "opsem::rvalue" :context ac :type "map lit" :instance i :stage nil 
    :ap i "elements" es :do 
    (update-push-acontext ac :stage "build value")
    (match :v (null es) T :do nil 
    :exit (update-push-acontext ac :stage "evaluating" 
                                   :av "entries" (mo :amap "Go value" "cell") 
                                   :ap "elements" (cdr es))
          (clear-update-eval-acontext ac :instance (car es) :av "elem type" (aget i "type" "elem type")))
)
; Добавляет вычисленную запись. Если все записи вычислены, то возвращает их список. Иначе отправляет вычислять далее.
(aspect "opsem::rvalue" :context ac :type "map lit" :instance i :stage "evaluating" 
    :ap ac "entries" ent :ap ac "elements" es :value ke :do 
    (aset ent (aget ke "key") (aget ke "value"))
    (match :v (null es) T :do ent 
    :exit (update-push-acontext ac :av "entries" ent :av "elements" (cdr es))
          (update-push-acontext ac :instance (car es)))
          (clear-update-eval-acontext ac :instance (aget (car es) "key") 
                                         :av "elem type" (aget i "type" "elem type"))
)
; Создаёт и возвращает значение карты.
(aspect "opsem::rvalue" :context ac :type "map lit" :instance i :stage "build value" 
    :value ent :do (mo "map value" :av "type" (aget i "type") :av "entries" ent)
)
; Отправляет вычислять значение записи.
(aspect "opsem::rvalue" :context ac :type "keyed elem" :instance i :stage nil 
    :value k :do (update-push-acontext ac :stage "eval value" :av "key" k)
                 (clear-update-eval-acontext ac :instance (aget i "value"))
)
; Создаёт и возвращает запись карты.
(aspect "opsem::rvalue" :context ac :type "keyed elem" :instance i :stage "eval value" 
    :ap ac "key" k :ap ac "elem type" et :value v :do (mo "keyed value" :av "key" k :av "value" 
        (mo "cell" :av "value" v :av "type" (mo "pointer type" :av "type" et)))
)

;; function lit
; Создаёт и возвращает значение функции.
(aspect "opsem::rvalue" :context ac :type "function lit" :instance i 
    :agent a :p (aget i "body" "all variables") ns :p nil c :do 
    (dolist (item ns) (setf c (aset c (aget a "variable cell" item))))  ; сохраняет ячейки памяти всех переменных до блока
    (mo "function value" :av "type"      (aget i "type")
                         :av "signature" (aget i "signature")
                         :av "body"      (aget i "body")
                         :av "closure"   c)
)


;; method lit
; Создаёт и возвращает значение метода.
(aspect "opsem::rvalue" :context ac :type "method lit" :instance i 
    :agent a :p (aget i "body" "all variables") ns :p nil c :do 
    (dolist (item ns) (setf c (aset c (aget a "variable cell" item))))  ; сохраняет ячейки памяти всех переменных до блока
    (mo "method value"  :av "type"      (aget i "type")
                        :av "signature" (aget i "signature")
                        :av "body"      (aget i "body")
                        :av "closure"   c)
)


;;; ================================================
;;; Expressions
;;; ================================================

;; variable ref
(aspect "opsem::lvalue" :context ac :type "variable ref" :instance i :agent a :do 
    (aget a "variable cell" i)
)
(aspect "opsem::rvalue" :context ac :type "variable ref" :instance i :agent a :do 
    (aget (aget a "variable cell" i) "value")
)

;; parenthized expression
(aspect "opsem::rvalue" :context ac :type "(1)" :instance i :do 
    (clear-update-eval-acontext ac :instance (aget i 1))
)

;; conversion
(aspect "opsem::rvalue" :context ac :type "conversion" :instance i :stage nil :do 
    (update-push-acontext ac :stage "type from")
    (clear-update-eval-acontext ac :instance (aget i "value"))
)

; Определяет тип вычисленного выражения
(aspect "opsem::rvalue" :context ac :type "conversion" :instance i :stage "type from" 
    :value tv :ap tv "type" ttv :do 
    (update-push-acontext ac :stage "build value")
    (clear-update-eval-acontext ac :av "typed value" tv :stage (nmatch 
    ; целочисленные и вещественные типы данных конвертируются между собой
    :v (is-instance ttv "int type")     T :exit "int type" 
    :v (is-instance ttv "float type")   T :exit "float type" 
    ; комплексные типы только между собой конвертируются
    :v (is-instance ttv "complex type") T :exit "complex type" 
    ; string, []byte тоже конвертируются между собой
    :v (is-instance ttv "string type")  T :exit "string type" 
    :v (is-instance ttv "slice type")   T :exit "[]byte type"))
)
; Сначала обрезаем старшие биты (если нужно), получаем x
; Полученный x находится в беззнаковом представлении. Если нужно, приводим к знаковому
(aspect "opsem::rvalue" :context ac :type "conversion" :instance i :stage "int type" 
    :ap ac "typed value" tv :ap tv "value" v :ap i "type" tp 
    :ap tp "bit size" bs :p (logand v (1- (ash 1 bs))) x :do 
    (nmatch 
    :v (is-instance tp "signed int type")   T :exit (if (> x (ash 1 (1- bs))) (- x (ash 1 bs)) x) 
    :v (is-instance tp "unsigned int type") T :exit x 
    :v (is-instance tp "float type")        T :exit (float v 0.0d0))
)
; Сначала обрезаем старшие биты (если нужно), получаем x
; В случае целых чисел нужно обрезать дробную часть, а для беззнаковых отдельно привести к знаковым
; Точность float type не зависит от bit size, а определяется lisp float
(aspect "opsem::rvalue" :context ac :type "conversion" :instance i :stage "float type" 
    :ap ac "typed value" tv :ap tv "value" v :ap i "type" tp 
    :ap tp "bit size" bs :p (logand v (1- (ash 1 bs))) x :do 
    (nmatch 
    :v (is-instance tp "signed int type")   T 
    :exit (let ((p (truncate x 1))) (if (> p (ash 1 (1- bs))) (- p (ash 1 bs)) p))
    :v (is-instance tp "unsigned int type") T :exit (truncate x 1)
    :v (is-instance tp "float type")        T :exit v)
)
; Комплексные значения можно приводить только к комплексным.
; Ничего делать не требуется, поскольку в данной реализации все дробные числа имеют lisp точность double-float
(aspect "opsem::rvalue" :context ac :type "conversion" :instance i :stage "complex type" :value v :do v)
; Нетривиальный случай только для среза битов
(aspect "opsem::rvalue" :context ac :type "conversion" :instance i :stage "string type" 
    :ap ac "typed value" tv :ap tv "value" v :ap i "type" tp :do 
    (nmatch 
    :v (is-instance tp "string type") T :exit v 
    :do (mapcar #'char-code (coerce v 'list)))
)
; В нетривиальном случае, сначала из среза вытаскивает значения, на которые он ссылается.
; Затем возвращает строку, преобразованню из списка.
(aspect "opsem::rvalue" :context ac :type "conversion" :instance i :stage "[]byte type" 
    :ap ac "typed value" tv :ap tv "value" sv :ap i "type" tp :ap sv "offset" ofs :do 
    (nmatch :v (is-instance tp "string type") nil :exit sv
    :p nil lst :p (aget sv "array" "elements") cs :do ; cs - элементы, на которые указывает срез (справа могут быть лишние)
    (dotimes (k ofs) (setf cs (cdr cs))) 
    (dotimes (k (aget sv "length") (reverse lst)) (setf lst (cons (aget (car cs) "value") lst)) (setf cs (cdr cs))) 
    (coerce (mapcar #'code-char lst) 'string))
)
; Создает и возвращает полученное значение
(aspect "opsem::rvalue" :context ac :type "conversion" :instance i :stage "build value" 
    :value v :ap i "type" tp :v (is-instance tp "slice type") nil :do 
    (mo "typed primitive" :av "type" tp :av "value" v)
)

;; method expression
(aspect "opsem::rvalue" :context ac :type "method expr" :instance i 
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
(aspect "opsem::rvalue" :context ac :type "selector expr" :instance i :stage nil
    :ap i "receiver" r :do 
    (update-push-acontext ac :stage "return value")
    (match :v (and (is-instance r "identifier") (aget a "type" r)) T 
    :do   (aget a "method value" r (aget i "name"))
    :exit (clear-update-eval-acontext ac :instance (aget i "receiver")))
)
; Иначе слева стоит структура, или указатель на стркутуру, который сначала нужно разыменовать.
(aspect "opsem::rvalue" :context ac :type "selector expr" :instance i :stage "return value" 
    :value r :ap r "type" tr :ap i "name" n :do 
    (nmatch :v tr "struct type"  :exit (aget r "fields" n "value") 
            :v tr "pointer type" :exit (aget r "target" "value" "fields" n "value"))
)

;; index expression
; Вычисляет индексированное хранилище (массив, срез, карта или строка)
(aspect "opsem::rvalue" :context ac :type "index expr" :instance i :stage nil :do 
    (update-push-acontext ac :stage "eval index")
    (clear-update-eval-acontext ac :instance (aget i "indexable"))
)
; Вычисляет индекс, по которому нужно будет взять элемент
(aspect "opsem::rvalue" :context ac :type "index expr" :instance i :stage "eval index" 
    :value indl :do 
    (update-push-acontext ac :stage "return value" :av "indexable" indl)
    (clear-update-eval-acontext ac :instance (aget i "index"))
)
; Возвращает взятый по индексу элемент
(aspect "opsem::rvalue" :context ac :type "index expr" :stage "return value" 
    :value index :ap ac "indexable" indl :ap indl "type" it :do 
    (nmatch :v it "array type"  :exit (aget (nth index (aget indl "elements")) "value")
            :v it "slice type"  :exit (aget (nth (+ (aget indl "offset") index) 
                (aget indl "array" "elements")) "value")
            :v it "map type"    :exit (aget (aget indl "entries" index) "value")
            :v it "string type" :exit (char (aget indl "value") index))
)

; Для lvalue всё вычисляется абсолютно так же
(aspect "opsem::lvalue" :context ac :type "indexable expr" :instance i :stage nil :do 
    (update-push-acontext ac :stage "eval index")
    (clear-update-eval-acontext ac :instance (aget i "indexable") :aspect "opsem::rvalue")
)
(aspect "opsem::lvalue" :context ac :type "index expr" :instance i :stage "eval index" 
    :value indl :do 
    (update-push-acontext ac :stage "return value" :av "indexable" indl)
    (clear-update-eval-acontext ac :instance (aget i "index") :aspect "opsem::rvalue")
)
; Строки являются неизменяемыми
(aspect "opsem::lvalue" :context ac :type "index expr" :stage "return value" 
    :value index :ap ac "indexable" indl :ap indl "type" it :do 
    (nmatch :v it "array type" :exit (nth index (aget indl "elements")) 
            :v it "slice type" :exit (nth (+ offset index) (aget indl "array" "elements"))
            :v it "map type"   :exit (aget indl "entries" index))
)

;; slice expr
; Сперва вычисляем атрибуты - выражения: slice, low, high, max
(aspect "opsem::rvalue" :context ac :type "slice expr" :instance i :stage nil :do 
    (update-push-acontext ac :stage "eval low")
    (clear-update-eval-acontext ac :instance (aget i "sequence"))
)
(aspect "opsem::rvalue" :context ac :type "slice expr" :instance i :stage "eval low" 
    :value s :do 
    (update-push-acontext ac :stage "eval high" :av "sequence" s)
    (clear-update-eval-acontext ac :instance (aget i "low"))
)
(aspect "opsem::rvalue" :context ac :type "slice expr" :instance i :stage "eval high" 
    :ap ac "sequence" s :value low :do
    (update-push-acontext ac :stage "eval max" :av "sequence" s :av "low" (if low low 0))
    (clear-update-eval-acontext ac :instance (aget i "high"))
)
(aspect "opsem::rvalue" :context ac :type "slice expr" :instance i :stage "eval max" 
    :ap ac "sequence" s :ap ac "low" low :value high :do 
    (update-push-acontext ac :stage "build value" :av "sequence" s :av "low" low :av "high" high)
    (clear-update-eval-acontext ac :instance (aget i "max"))
)
; Определяем тип последовательности, от которой нужно взять срез
(aspect "opsem::rvalue" :context ac :type "slice expr" :stage "build value" 
    :ap ac "sequence" s :ap ac "low" low :ap ac "high" high :value cap :ap s "type" st :do 
    (clear-update-eval-acontext ac :stage (otype st) 
        :av "sequence" s :av "low" low :av "high" high :av "cap" cap)
)
; Если срез нужно взять от массива
(aspect "opsem::rvalue" :context ac :type "slice expr" :stage "array type" 
    :ap ac "sequence" s :ap ac "low" low :ap ac "high" :ap ac "cap" cap
    :ap s "type" st :p (length (aget s "elements")) len :do 
    (if (not high) (aset high len))
    (if (not cap) (aset cap (- len low)))
    (mo "slice value" 
        :av "type" (mo "slice type" :av "elem type" (aget st "elem type")) 
        :av "array" s 
        :av "offset" low 
        :av "length" high - low 
        :av "capacity" cap
    )
)
; Если срез нужно взять от указателя на массив, разыменовываем, и после как для обычного массива
(aspect "opsem::rvalue" :context ac :type "slice expr" :stage "pointer type" 
    :ap ac "sequence" s :ap ac "low" low :ap ac "high" high :ap ac "cap" cap :do 
    (clear-update-eval-acontext ac :stage "array type" :av "sequence" (aget s "value"))
)
; Если срез нужно взять от среза
(aspect "opsem::rvalue" :context ac :type "slice expr" :stage "slice type" 
    :ap ac "sequence" s :ap ac "low" low :ap ac "high" high :ap ac "cap" cap 
    :p (length (aget s "array" "type" "len")) len :do 
    (if (not high) (aset high len))
    (if (not cap) (aset cap (- len low)))
    (mo "slice value" 
        :av "type" (aget s "type")
        :av "array" (aget s "array")
        :av "offset" (+ (aget s "offset") low)
        :av "length" (aget s "length")
        :av "capacity" (aget s "capacity")
    )
)
; Если срез нужно взять от строки, то возвращаем просто строку (т.к. они неизменяемы)
(aspect "opsem::rvalue" :context ac :type "slice expr" :stage "string type" 
    :p (aget ac "sequence" "value") s :ap ac "low" low :ap ac "high" high :do 
    (if (not high) (aset high (length s)))
    (subseq s low high)
)

;; function call
; Отправляет вычислять функцию, получаем значение функции
(aspect "opsem::rvalue" :context ac :type "function call" :instance i :stage nil :do 
    (update-push-acontext ac :stage "eval arguments")
    (clear-update-eval-acontext ac :instance (aget i "function"))
)
; Отправляет вычислять значения параметров
(aspect "opsem::rvalue" :context ac :type "function call" :instance i :stage "eval arguments" 
    :value f :ap i "arguments" as :do 
    (update-push-acontext ac :stage "copy parameters" :av "function" f)
    (match :v (null as) T :do nil 
    :exit (update-push-acontext ac :stage "evaluating" :av "arguments" nil :av "left" (cdr as))
          (clear-update-eval-acontext ac :instance (car as)))
)
; Вычисляет значение очередного параметра
(aspect "opsem::rvalue" :context ac :type "function call" :stage "evaluating" 
    :ap ac "arguments" as :ap ac "left" left :value v :p (cons v as) nas :do 
    (match :v (null left) T :do (reverse nas) 
    :exit (update-push-acontext ac :av "arguments" (cdr as) :av "left" (cdr left))
          (clear-update-eval-acontext ac :instance (car as)))
)
; Сохраняет старые значения параметров
; Если результат функции именованный, то отправляет сохранять для них старые ячейки, и вычислять значения по умолчанию
(aspect "opsem::rvalue" :context ac :type "function call" :stage "copy parameters" 
    :ap ac "function" f :ap f "signature" sgn :ap sgn "result" r :value as :agent a :p nil dcs :do 
    (let ((args as)) (dolist (p (aget sgn "parameters")) 
        ; сохранить старую ячейку памяти
        (setf dcs (cons (aget a "variable cell" (aget p "name")) dcs))
        ; установить новое значение для затеняющего (наверное) параметра
        (aset a "variable cell" (aget p "name") (mo "cell" :av "type" (aget p "type") :av "value" (car args)))
        (setf args (cdr args))))
    (update-push-acontext ac :stage "copy closure" :av "function" f)
    (match :v (null r) nil :v (is-instance (car r) "param decl") T :do  ; если результат функции именованный
        (update-push-acontext ac :stage "copying result" :av "left" r :av "done" dcs)
        (clear-update-eval-acontext ac :instance (aget (car r) "type") :aspect "default value by type")
    :exit dcs)
)
; Сохраняет старые ячейки для именованного результата функции, и вычисляет для них значения по умолчанию
(aspect "opsem::rvalue" :context ac :type "function call" :stage "copying result" 
    :ap ac "left" l :ap ac "done" done :value v :agent a :ap (car l) "name" n 
    :p (cons (aget a "variable cell" n) done) nd :do 
    (aset a "variable cell" n (mo "cell" :av "type" (aget (car l) "type") :av "value" v))
    (match :v (null l) T :do nd 
    :exit (update-push-acontext ac :av "left" (cdr "left") :av "done" nd)
          (clear-update-eval-acontext ac :instance (aget (car l) "type") :aspect "default value by type"))
)
; Сохраняет старые значения переменных из замыкания функции
(aspect "opsem::rvalue" :context ac :type "function call" :stage "copy closure" 
    :ap ac "function" f :value dcs :ap f "closure" cl :agent a :do 
    (dolist (n (attributes cl)) (setf dcs (cons (aget cl n) dcs)) 
        (setf a "variable cell" n (mo "cell" :av "type" (aget cl n "type") :av "value" (aget cl n "value"))))
    (update-push-acontext ac :stage "variable back" :av "function" f :av "cells" (reverse dcs))
    (clear-update-eval-acontext ac :instance (aget f "body"))
)
; Возвращаем прежние значения функции
(aspect "opsem::rvalue" :context ac :type "function call" :stage "variable back" 
    :ap ac "function" f :ap ac "cells" cs :ap f "signature" sgn :ap sgn "result" r 
    :ap f "closure" cl :value v :do 
    ; возвращаем старые значения для параметров фукнции
    (dolist (p (aget sgn "parameters")) (aset a "variable cell" (aget p "name") (car cs)) (setf cs (cdr cs)))
    ; если результат функции именованный
    (match :v (null r) nil :v (is-instance (car r) "param decl") T :do
        (dolist (p r) (aset a "variable cell" (aget p "name") (car cs)) (setf cs (cdr cs))))
    ; возвращаем старые значения для переменных замыкания функции
    (dolist (n (attributes cl)) (setf a "variable cell" n (car cs)) (setf cs (cdr cs)))
    (car v)  ; вернуть то, что получилось после выполнения тела функции
)

;; method call
; Вычисляем получателя метода
(aspect "opsem::rvalue" :context ac :type "method call" :instance i :stage nil :do 
    (update-push-acontext ac :stage "to function")
    (clear-update-eval-acontext ac :instance (aget i "receiver"))
)
; Преобразуем метод в функцию
(aspect "opsem::rvalue" :context ac :type "method call" :instance i :stage "to function" 
    :value rec :do 
    (update-push-acontext ac :stage "eval call")
    (clear-update-eval-acontext ac :instance (mo "method expr" 
        :av "receiver type" (aget rec "type") :av "name" (aget i "method")))
)
; Исполняем вызов функции на преобразованной из метода
(aspect "opsem::rvalue" :context ac :type "method call" :instance i :stage "eval call" :value f :do 
    (clear-update-eval-acontext ac :instance (mo "function call" 
        :av "function" f :av "arguments" (aget i "arguments")))
)

;;; Unary expressions
(aspect "opsem::rvalue" :context ac :type "unary expression" :instance i :stage nil :do 
    (update-push-acontext ac :stage "apply")
    (clear-update-eval-acontext ac :instance (aget i 1))
)

; Сначала считаем для просто чисел, а потом только приводим результат к необходимому типу.
; Эта вспомогательная функция производит приведение чисел к нужному типу, остальные примитивы не меняет.
; То есть происходит обрезание до нужного числа битов и приведение из беззнаковой в знаковую форму.
(defun convert-int-to-type (tp raw)
    (mo "typed primitive" :av "type" tp :av "value" 
        (if (not (is-instance tp "int type")) raw  ; если не целочисленный примитив
            (let* ((bs (aget tp "bit size")) (v (mod raw (ash 1 bs))))
                (if (or (is-instance tp "unsigned int type") (< v (ash 1 (1- bs)))) v 
                    (- v (ash 1 (1- bs)))))))  ; если нужно привести от беззнакового к знаковому
)

;; unary plus
(aspect "opsem::rvalue" :context ac :type "+1" :stage "apply" :value v :do v)

;; unary minus
; Вычисляем значение операции и приводим результат к нужному типу
(aspect "opsem::rvalue" :context ac :type "-1" :stage "apply" :value pr 
    :ap pr "value" v :ap pr "type" tp :do (convert-int-to-type tp (- v))
)

;; bitwise not
(aspect "opsem::rvalue" :context ac :type "^1" :stage "apply" :value pr 
    :ap pr "value" v :ap pr "type" tp :do (convert-int-to-type tp (lognot v))
)

;; logical not
(aspect "opsem::rvalue" :context ac :type "!1" :stage "apply" :value v :do 
    (mo "typed primitive" :av "type" (aget v "type") :av "value" (not (aget v "value")))
)

;; pointer dereference
; Разыменование применимо только к ячейкам памяти cell
(aspect "opsem::rvalue" :context ac :type "*1" :stage "apply" 
    :value tv :ap tv "value" v :do  ; tp - pointer type; v - cell
    (mo "typed primitive" :av "type" (aget tv "type") :av "value" (aget v "value"))
)

(aspect "opsem::lvalue" :context ac :type "*1" :instance i :stage nil :do 
    (update-push-acontext ac :stage "apply")
    (clear-update-eval-acontext ac :instance (aget i 1))
)
(aspect "opsem::lvalue" :context ac :type "*1" :stage "apply" :value v :do (aget v "value"))

;; address of
(aspect "opsem::rvalue" :context ac :type "&1" :instance i :stage "apply" 
    :value tv :ap tv "type" tp :ap tv "value" v :do 
    (mo "typed primitive" :av "type" (co "pointer type" :av "type" tp) 
        :av "value" (mo "cell" :av "value" v :av "type" tp))
)

;;; Binary expressions
(aspect "opsem::rvalue" :context ac :type "binary expression" :instance i :stage nil :do 
    (update-push-acontext ac :stage "apply 1")
    (clear-update-eval-acontext ac :instance (aget i 1))
)

;; logical OR
(aspect "opsem::rvalue" :context ac :type "1||2" :instance i :stage "apply 1" :value v :do 
    (match :v (aget v "value") T 
    :do (mo "typed primitive" :av "type" (co "bool type") :av "value" T) 
    :exit (update-push-acontext ac :stage "apply 2")
          (clear-update-eval-acontext ac :instance (aget i 2)))
)
(aspect "opsem::rvalue" :context ac :type "1||2" :stage "apply 2" :value v :do 
    (mo "typed primitive" :av "type" (co "bool type") :av "value" (aget v "value"))
)

;; logical AND
(aspect "opsem::rvalue" :context ac :type "1&&2" :instance i :stage "apply 1" :value v :do 
    (match :v (aget v "value") nil 
    :do (mo "typed primitive" :av "type" (co "bool type") :av "value" nil) 
    :exit (update-push-acontext ac :stage "apply 2")
          (clear-update-eval-acontext ac :instance (aget i 2)))
)
(aspect "opsem::rvalue" :context ac :type "1&&2" :stage "apply 2" :value v :do
    (mo "typed primitive" :av "type" (co "bool type") :av "value" (aget v "value"))
)

;; addition
(aspect "opsem::rvalue" :context ac :type "1+2" :instance i :stage "apply 1" :value v :do 
    (update-push-acontext ac :stage "apply 2" :av 1 v)
    (clear-update-eval-acontext ac :instance (aget i 2))
)
(aspect "opsem::rvalue" :context ac :type "1+2" :stage "apply 2" 
    :ap ac 1 f :ap f "type" tp :ap f "value" fv :value s :ap s "value" sv :do 
    (convert-int-to-type tp (+ fv sv))
)

;; substraction
(aspect "opsem::rvalue" :context ac :type "1-2" :instance i :stage "apply 1" :value v :do 
    (update-push-acontext ac :stage "apply 2" :av 1 v)
    (clear-update-eval-acontext ac :instance (aget i 2))
)
(aspect "opsem::rvalue" :context ac :type "1-2" :stage "apply 2" 
    :ap ac 1 f :ap f "type" tp :ap f "value" fv :value s :ap s "value" sv :do 
    (convert-int-to-type tp (- fv sv))
)

;; multiplication
(aspect "opsem::rvalue" :context ac :type "1*2" :instance i :stage "apply 1" :value v :do 
    (update-push-acontext ac :stage "apply 2" :av 1 v)
    (clear-update-eval-acontext ac :instance (aget i 2))
)
(aspect "opsem::rvalue" :context ac :type "1*2" :stage "apply 2" 
    :ap ac 1 f :ap f "type" tp :ap f "value" fv :value s :ap s "value" sv :do 
    (convert-int-to-type tp (* fv sv))
)

;; division
(aspect "opsem::rvalue" :context ac :type "1/2" :instance i :stage "apply 1" :value v :do 
    (update-push-acontext ac :stage "apply 2" :av 1 v)
    (clear-update-eval-acontext ac :instance (aget i 2))
)
(aspect "opsem::rvalue" :context ac :type "1/2" :stage "apply 2" 
    :ap ac 1 f :ap f "type" tp :ap f "value" fv :value s :ap s "value" sv :do 
    (convert-int-to-type tp (/ fv sv))
)

;; remainder
(aspect "opsem::rvalue" :context ac :type "1%2" :instance i :stage "apply 1" :value v :do 
    (update-push-acontext ac :stage "apply 2" :av 1 v)
    (clear-update-eval-acontext ac :instance (aget i 2))
)
(aspect "opsem::rvalue" :context ac :type "1%2" :stage "apply 2" 
    :ap ac 1 f :ap f "type" tp :ap f "value" fv :value s :ap s "value" sv :do 
    (convert-int-to-type tp (rem fv sv))
)

;; left shift
(aspect "opsem::rvalue" :context ac :type "1<<2" :instance i :stage "apply 1" :value v :do 
    (update-push-acontext ac :stage "apply 2" :av 1 v)
    (clear-update-eval-acontext ac :instance (aget i 2))
)
(aspect "opsem::rvalue" :context ac :type "1<<2" :stage "apply 2" 
    :ap ac 1 f :ap f "type" tp :ap f "value" fv :value s :ap s "value" sv :do 
    (convert-int-to-type tp (ash fv sv))
)

;; right shift
(aspect "opsem::rvalue" :context ac :type "1>>2" :instance i :stage "apply 1" :value v :do 
    (update-push-acontext ac :stage "apply 2" :av 1 v)
    (clear-update-eval-acontext ac :instance (aget i 2))
)
(aspect "opsem::rvalue" :context ac :type "1>>2" :stage "apply 2" 
    :ap ac 1 f :ap f "type" tp :ap f "value" fv :value s :ap s "value" sv :do 
    (convert-int-to-type tp (ash fv (- sv)))
)

;; bitwise AND
(aspect "opsem::rvalue" :context ac :type "1&2" :instance i :stage "apply 1" :value v :do 
    (update-push-acontext ac :stage "apply 2" :av 1 v)
    (clear-update-eval-acontext ac :instance (aget i 2))
)
(aspect "opsem::rvalue" :context ac :type "1&2" :stage "apply 2" 
    :ap ac 1 f :ap f "type" tp :ap f "value" fv :value s :ap s "value" sv :do 
    (convert-int-to-type tp (logand fv sv))
)

;; bitwise AND NOT
(aspect "opsem::rvalue" :context ac :type "1&^2" :instance i :stage "apply 1" :value v :do 
    (update-push-acontext ac :stage "apply 2" :av 1 v)
    (clear-update-eval-acontext ac :instance (aget i 2))
)
(aspect "opsem::rvalue" :context ac :type "1&^2" :stage "apply 2" 
    :ap ac 1 f :ap f "type" tp :ap f "value" fv :value s :ap s "value" sv :do 
    (convert-int-to-type tp (logand fv (lognot sv)))
)

;; bitwise OR
(aspect "opsem::rvalue" :context ac :type "1|2" :instance i :stage "apply 1" :value v :do 
    (update-push-acontext ac :stage "apply 2" :av 1 v)
    (clear-update-eval-acontext ac :instance (aget i 2))
)
(aspect "opsem::rvalue" :context ac :type "1|2" :stage "apply 2" 
    :ap ac 1 f :ap f "type" tp :ap f "value" fv :value s :ap s "value" sv :do 
    (convert-int-to-type tp (logior fv sv))
)

;; bitwise XOR
(aspect "opsem::rvalue" :context ac :type "1^2" :instance i :stage "apply 1" :value v :do 
    (update-push-acontext ac :stage "apply 2" :av 1 v)
    (clear-update-eval-acontext ac :instance (aget i 2))
)
(aspect "opsem::rvalue" :context ac :type "1^2" :stage "apply 2" 
    :ap ac 1 f :ap f "type" tp :ap f "value" fv :value s :ap s "value" sv :do 
    (convert-int-to-type tp (logxor fv sv))
)

;;; Relation expressions
(aspect "opsem::rvalue" :context ac :type "1==2" :instance i :stage "apply 1" :value v :do 
    (update-push-acontext ac :stage "apply 2" :av 1 v)
    (clear-update-eval-acontext ac :instance (aget i 2))
)
(aspect "opsem::rvalue" :context ac :type "1==2" :stage "apply 2" 
    :ap ac 1 f :ap f "type" tp :ap f "value" fv :value s :ap s "value" sv :do 
    (convert-int-to-type tp (= fv sv))
)

(aspect "opsem::rvalue" :context ac :type "1!=2" :instance i :stage "apply 1" :value v :do 
    (update-push-acontext ac :stage "apply 2" :av 1 v)
    (clear-update-eval-acontext ac :instance (aget i 2))
)
(aspect "opsem::rvalue" :context ac :type "1!=2" :stage "apply 2" 
    :ap ac 1 f :ap f "type" tp :ap f "value" fv :value s :ap s "value" sv :do 
    (convert-int-to-type tp (not (= fv sv)))
)

(aspect "opsem::rvalue" :context ac :type "1<2" :instance i :stage "apply 1" :value v :do 
    (update-push-acontext ac :stage "apply 2" :av 1 v)
    (clear-update-eval-acontext ac :instance (aget i 2))
)
(aspect "opsem::rvalue" :context ac :type "1<2" :stage "apply 2" 
    :ap ac 1 f :ap f "type" tp :ap f "value" fv :value s :ap s "value" sv :do 
    (convert-int-to-type tp (< fv sv))
)

(aspect "opsem::rvalue" :context ac :type "1<=2" :instance i :stage "apply 1" :value v :do 
    (update-push-acontext ac :stage "apply 2" :av 1 v)
    (clear-update-eval-acontext ac :instance (aget i 2))
)
(aspect "opsem::rvalue" :context ac :type "1<=2" :stage "apply 2" 
    :ap ac 1 f :ap f "type" tp :ap f "value" fv :value s :ap s "value" sv :do 
    (convert-int-to-type tp (<= fv sv))
)

(aspect "opsem::rvalue" :context ac :type "1>2" :instance i :stage "apply 1" :value v :do 
    (update-push-acontext ac :stage "apply 2" :av 1 v)
    (clear-update-eval-acontext ac :instance (aget i 2))
)
(aspect "opsem::rvalue" :context ac :type "1>2" :stage "apply 2" 
    :ap ac 1 f :ap f "type" tp :ap f "value" fv :value s :ap s "value" sv :do 
    (convert-int-to-type tp (> fv sv))
)

(aspect "opsem::rvalue" :context ac :type "1>=2" :instance i :stage "apply 1" :value v :do 
    (update-push-acontext ac :stage "apply 2" :av 1 v)
    (clear-update-eval-acontext ac :instance (aget i 2))
)
(aspect "opsem::rvalue" :context ac :type "1>=2" :stage "apply 2" 
    :ap ac 1 f :ap f "type" tp :ap f "value" fv :value s :ap s "value" sv :do 
    (convert-int-to-type tp (>= fv sv))
)


;;; ================================================
;;; Blocks
;;; ================================================

; Сохраняет ячейки всех переменных, встречающихся в этом блоке. При декларации будут созданы новые ячейки.
(aspect "opsem" :context ac :type "block" :instance i :stage nil 
    :ap i "statements" sts :ap i "decl variables" avs :p nil dv :agent a :do 
    (aset i "variable cells" (dolist 
        (item avs (reverse dv)) 
        (setf dv (cons (aget a "variable cell" item) dv))))
    (update-push-acontext ac :stage "variable back")
    (clear-update-eval-acontext ac :stage "evaluating statement" :av "left" sts)
)
; Вычисляет очередной оператор блока (очередную инструкцию блока).
(aspect "opsem" :context ac :type "block" :instance i :stage "evaluating statement" 
    :ap ac "left" left :v (null left) nil :ap i "statements" sts :do 
    (update-push-acontext ac :av "left" (cdr left))
    (clear-update-eval-acontext ac :instance (car left) :av "block" i)
)
; Восстанавливает старые ячейки памяти декларированным в блоке (важны только затенённые) переменным.
(aspect "opsem" :context ac :type "block" :instance i :stage "variable back" :do 
    (dolist (item (aget i "decl variables")) (aset a "variable cell" item (aget item "variable cells")))
)


;;; ================================================
;;; Declarations
;;; ================================================

;; type decl
(aspect "opsem" :context ac :type "type decl" :instance i :agent a :do 
    (aset a "type" (aget i "name") (aget i "type"))
)

;; var decl
; Если задаются без значений, то вычилсяем значения по типам переменных.
; Иначе все переменные задаются с явно указанными значениями.
(aspect "opsem" :context ac :type "var decl" :instance i :stage nil 
    :ap ac "block" b :ap i "names" ns :ap i "values" vs :ap i "types" ts :do 
    (match :v (null vs) T 
    :do (update-push-acontext ac :stage "declarating defaults" 
                                 :av "names" ns :av "types" (cdr ts) :av "block" b)
        (clear-update-eval-acontext ac :aspect "default value by type" :instance (car ts))
    :exit (update-push-acontext ac :stage "evaluating values" 
          :av "names" ns :av "types" ts :av "values" (cdr vs) :av "block" b)
          (clear-update-eval-acontext ac :instance (car vs)))
)
; Декларируем очередную переменную по значению по умолчанию соответсвующего типа.
(aspect "opsem" :context ac :type "var decl" :instance i :stage "declarating defaults" 
    :ap ac "names" ns :ap ac "types" ts :ap ac "block" b :value v :agent a :do 
    (aset b "variable cells" (car ns) (aget a "variable cell" (car ns)))  ; сохраняем в блок информацию о старой ячейке переменной
    (aset a "variable cell" (car ns) (mo "cell" :av "value" v 
                                                :av "type" (co "pointer type" :av "type" (car ts))))
    (match :v (null ts) nil :do 
    (update-push-acontext ac :av "names" (cdr ns) :av "types" (cdr ts) :av "block" b)
    (clear-update-eval-acontext ac :aspect "default value by type" :instance (car ts)))
)
; Декларируем очередную переменную по явно заданному значению.
(aspect "opsem" :context ac :type "var decl" :instance i :stage "evaluating values" 
    :ap ac "names" ns :ap ac "values" vs :ap ac "types" ts :ap ac "block" b :value v :agent a :do 
    (aset b "variable cells" (car ns) (aget a "variable cell" (car ns)))  ; сохраняем в блок информацию о старой ячейке переменной
    (aset a "variable cell" (car ns) (mo "cell" :av "value" v 
                                                :av "type" (co "pointer type" :av "type" (car ts))))
    (match :v (null vs) nil :do 
    (update-push-acontext ac :av "names" (cdr ns) :av "types" (cdr ts) :av "values" (cdr vs) :av "block" b)
    (clear-update-eval-acontext ac :instance (car vs)))
)

;; function decl
(aspect "opsem" :context ac :type "function decl" :instance i :stage nil :do 
    (update-push-acontext ac :stage "decl")
    (clear-update-eval-acontext ac :instance (aget i "value"))
)
(aspect "opsem" :context ac :type "function decl" :instance i :stage "decl" 
    :value v :agent a :do (aset a "function value" (aget i "name") v)
)

;; method decl
(aspect "opsem" :context ac :type "method decl" :instance i :stage nil :do 
    (update-push-acontext ac :stage "decl")
    (clear-update-eval-acontext ac :instance (aget i "value"))
)
(aspect "opsem" :context ac :type "method decl" :instance i :stage "decl" 
    :value v :agent a :do (aset a "method value" (aget i "value" "type" "receiver type") (aget i "name") v)
)


;;; ================================================
;;; Statements
;;; ================================================

;; label
(aspect "opsem" :context ac :type "label" :instance i :do 
    (clear-update-eval-acontext ac :instance (aget i "statement") 
    :av "block" (aget ac "block") :av "label" (aget i "name"))
)

;; empty statement
(aspect "opsem" :context ac :type "empty stmt")

;; increment statement
(aspect "opsem" :context ac :type "1++ stmt" :instance i :stage nil :do 
    (update-push-acontext ac :stage "apply")
    (clear-update-eval-acontext ac :aspect "opsem::lvalue" :instance (aget i 1))
)
; Здесь v должно иметь тип "cell", как любое lvalue значение в модели
(aspect "opsem" :context ac :type "1++ stmt" :instance i :stage "apply" :value v :do 
    (aset v "value" (convert-int-to-type (aget i "type") (1+ (aget v "value"))))
)

;; decrement statement
(aspect "opsem" :context ac :type "1-- stmt" :instance i :stage nil :do 
    (update-push-acontext ac :stage "apply")
    (clear-update-eval-acontext ac :aspect "opsem::lvalue" :instance (aget i 1))
)
; Здесь v должно иметь тип "cell", как любое lvalue значение в модели
(aspect "opsem" :context ac :type "1-- stmt" :instance i :stage "apply" :value v :do 
    (aset v "value" (convert-int-to-type (aget i "type") (1- (aget v "value"))))
)

;;; Assignment statements
; Вычисляет левый аргумент в позиции lvalue. Он должен иметь тип "cell"
(aspect "opsem" :context ac :type "assignment stmt" :instance i :stage nil :do 
    (update-push-acontext ac :stage "eval 2")
    (clear-update-eval-acontext ac :aspect "opsem::lvalue" :instance (aget i 1))
)
; Вычисляет правый аргумент в позиции rvalue
(aspect "opsem" :context ac :type "assignment stmt" :instance i :stage "eval 2" :value v :do 
    (update-push-acontext ac :stage "apply" :ac 1 v)
    (clear-update-eval-acontext ac :aspect "opsem::rvalue" :instance (aget i 2))
)

(aspect "opsem" :context ac :type "1=2" :stage "apply" :ap ac 1 f :value s :do 
    (aset f "value" s)  ; Присваивать допускается только значения того же типа
)

(aspect "opsem" :context ac :type "1+=2" :stage "apply" :ap ac 1 f :value s :do 
    (aset f "value" (convert-int-to-type (aget f "type") (+ (aget f "value") (aget s "value"))))
)

(aspect "opsem" :context ac :type "1-=2" :stage "apply" :ap ac 1 f :value s :do 
    (aset f "value" (convert-int-to-type (aget f "type") (- (aget f "value") (aget s "value"))))
)

(aspect "opsem" :context ac :type "1*=2" :stage "apply" :ap ac 1 f :value s :do 
    (aset f "value" (convert-int-to-type (aget f "type") (* (aget f "value") (aget s "value"))))
)

(aspect "opsem" :context ac :type "1/=2" :stage "apply" :ap ac 1 f :value s :do 
    (aset f "value" (convert-int-to-type (aget f "type") (/ (aget f "value") (aget s "value"))))
)

(aspect "opsem" :context ac :type "1<<=2" :stage "apply" :ap ac 1 f :value s :do 
    (aset f "value" (convert-int-to-type (aget f "type") (ash (aget f "value") (aget s "value"))))
)

(aspect "opsem" :context ac :type "1>>=2" :stage "apply" :ap ac 1 f :value s :do 
    (aset f "value" (convert-int-to-type (aget f "type") (ash (aget f "value") (- (aget s "value")))))
)

(aspect "opsem" :context ac :type "1^=2" :stage "apply" :ap ac 1 f :value s :do 
    (aset f "value" (convert-int-to-type (aget f "type") (logxor (aget f "value") (aget s "value"))))
)

(aspect "opsem" :context ac :type "1|=2" :stage "apply" :ap ac 1 f :value s :do 
    (aset f "value" (convert-int-to-type (aget f "type") (logior (aget f "value") (aget s "value"))))
)

(aspect "opsem" :context ac :type "1%=2" :stage "apply" :ap ac 1 f :value s :do 
    (aset f "value" (convert-int-to-type (aget f "type") (rem (aget f "value") (aget s "value"))))
)

(aspect "opsem" :context ac :type "1&=2" :stage "apply" :ap ac 1 f :value s :do 
    (aset f "value" (convert-int-to-type (aget f "type") (logand (aget f "value") (aget s "value"))))
)

(aspect "opsem" :context ac :type "1&^=2" :stage "apply" :ap ac 1 f :value s :do 
    (aset f "value" (convert-int-to-type (aget f "type") (logand (aget f "value") (lognot (aget s "value")))))
)

;; if statement
(aspect "opsem" :context ac :type "if stmt" :instance i :stage nil :do 
    (update-push-acontext ac :stage "apply")
    (clear-update-eval-acontext ac :instance (aget i "condition") :aspect "opsem::rvalue")
)
(aspect "opsem" :context ac :type "if stmt" :instance i :stage "apply" :value c :do 
    (clear-update-eval-acontext ac :instance (aget i (if c "then" "else")))
)

;;; switch statement

;; expression switch statement
; Сначала вычисляем выражение, которое будем сравнивать
(aspect "opsem" :context ac :type "expr switch stmt" :instance i :stage nil :do 
    (update-push-acontext ac :stage "apply cont" :av "block" (aget ac "block"))
    (clear-update-eval-acontext ac :instance (aget i "controlled") :aspect "opsem::rvalue")
)
; Вычисляем первую ветку case, запускаем вычисление следующих веток
(aspect "opsem" :context ac :type "expr switch stmt" :instance i :stage "apply cont" :value cont 
    :ap i "cases" cs :v (null cs) nil :ap ac "block" b :do 
    (match :v cont nil :p cont T :do  ; синтаксический сахар языка Go
        (update-push-acontext ac :stage "evaluating cases" :av "cont" cont :av "left" (cdr cs) :av "block" b)
        (clear-update-eval-acontext ac :instance (car cs) :av "cont" cont) :av "block" b)
)
; Проверяем, остались ли ещё ветки. Проверяем, смогла ли сработать последняя ветка :value = T, или нет:
; expr case clause возвращает, нашлось ли в нём подходящее значение
(aspect "opsem" :context ac :type "expr switch stmt" :instance i :stage "evaluating cases" 
    :ap ac "cont" cont :ap ac "left" left :v (null left) nil :value v :v v nil :ap ac "block" b :do 
    (update-push-acontext ac :av "cont" cont :av "left" (cdr left) :av "block" b)
    (clear-update-eval-acontext ac :instance (car left) :av "cont" cont :av "block" b)
)
; Вычисляем значение первого случая в ветке. Запускаем вычисление последующих значений ветки
(aspect "opsem" :context ac :type "expr case clause" :instance i :stage nil 
    :ap ac "cont" cont :ap i "cases" cs :ap ac "block" b :do 
    (match :v (null cs) T :do nil :exit 
        (update-push-acontext ac :stage "evaluating" :av "cont" cont :av "left" (cdr cs) :av "block" b)
        (clear-update-eval-acontext ac :instance (mo "1==2" :av 1 cont :av 2 (car cs)) 
                                       :aspect "opsem::rvalue") :av "block" b)
)
; Проверяем, смог ли сработать предыдущий случай ветки. Проверяем следующие значения
(aspect "opsem" :context ac :type "expr case clause" :instance i :stage "evaluating" 
    :value v :ap ac "cont" cont :ap ac "left" left :ap ac "block" b :do 
    (match :v v nil  ; если предыдущий случай не подходит
    :do (nmatch :v (null left) T :exit nil  ; если ничего не подошло
        :v (otype (car left)) "default"  ; если дошли до ветки default (последняя из веток, если есть)
        :exit (clear-update-eval-acontext ac :stage "evaluating body" 
                                             :av "left" (aget i "statements") :av "block" b)
        ; если остались не рассмотренные случаи
        :do (update-push-acontext ac :av "cont" cont :av "left" (cdr cs) :av "block" b)
            (clear-update-eval-acontext ac :instance (mo "1==2" :av 1 cont :av 2 (car cs))
                                           :aspect "opsem::rvalue") :av "block" b)
    ; если предыдущий случай подходит, то выполняем тело данной ветки
    :exit (clear-update-eval-acontext ac :stage "evaluating body" 
                                         :av "left" (aget i "statements") :av "block" b))
)
; Выполняет тело подошедшей ветки case
(aspect "opsem" :context ac :type "expr case clause" :instance i :stage "evaluating body" 
    :ap ac "left" left :ap ac "block" b :do 
    (match :v (null left) T :do T :exit 
        (update-push-acontext ac :av "left" (cdr left) :av "block" b)
        (clear-update-eval-acontext ac :instance (car left) :av "block" b))
)

;;; for statement

;; for condition
; Вычисляем условное выражение
(aspect "opsem" :context ac :type "for condition" :instance i :stage nil :do 
    (update-push-acontext ac :stage "apply")
    (clear-update-eval-acontext ac :instance (aget i "condition") :aspect "opsem::rvalue")
)
; Если вычисленное значение правдиво, то выполняем тело и возвращаемся к предыдущему шагу
(aspect "opsem" :context ac :type "for condition" :instance i :stage "apply" :value v :v v T :do 
    (update-push-acontext ac :stage nil)
    (clear-update-eval-acontext ac :instance (aget i "body"))
)

;; for clause
; Вычисляем условное выражение
(aspect "opsem" :context ac :type "for clause" :instance i :stage nil :do 
    (update-push-acontext ac :stage "apply")
    (clear-update-eval-acontext ac :instance (aget i "condition") :aspect "opsem::rvalue")
)
; Если оно правдиво, то выполняем тело
(aspect "opsem" :context ac :type "for clause" :instance i :stage "apply" :value v :v v T :do 
    (update-push-acontext ac :stage "post")
    (clear-update-eval-acontext ac :instance (aget i "body"))
)
; После вычисления тела, выполняем оператор шага post, и возвращаемся к вычислению условного выражения
(aspect "opsem" :context ac :type "for clause" :instance i :stage "post" :do 
    (update-push-acontext ac :stage nil)
    (clear-update-eval-acontext ac :instance (aget i "post"))
)

; Эта функция копирует список ячеек, заменяя сами ячейки, но не меняя значения. Не идёт вглубь
(defun copy-cells (lst) 
    (let ((r nil)) (dolist (c (reverse lst) r) 
        (setq r (cons (mo "cell" :av "type" (aget c "type") :av "value" (aget c "value")) r))))
)

;; for range indexable
(aspect "opsem" :context ac :type "for range indexable" :instance i :stage nil 
    :ap i "indexable" ind :do 
    ; Могут быть следующие стадии: array type, slice type, string type
    (update-push-acontext ac :stage (otype (aget ind "type")))
    (clear-update-eval-acontext ac :instance ind :aspect "opsem::rvalue")
)
; Сведём случай среза к массиву
(aspect "opsem" :context ac :type "for range indexable" :instance i :stage "slice type" 
    :value sl :ap sl "offset" ofst :ap sl "length" len :do 
    ; Атрибуты, кроме среза, не меняются
    (clear-update-eval-acontext ac :instance (mo "for range indexable" 
    :av "index" (aget i "index") 
    :av "value" (aget i "value")
    :av "operation" (aget i "operation") 
    :av "indexable" (mo "array value" 
        :av "type" (co "array type" :av "len" len :ap "elem type" (aget sl "type" "elem type"))
        :av "elements" (copy-cells (subseq (aget sl (aseq "array" "elements")) ofst (+ ofst len))))
    :av "body" (aget i "body")))
)
; Сведём случай строки к массиву
(aspect "opsem" :context ac :type "for range indexable" :instance i :stage "string type" 
    :value pr :ap pr "value" s :do 
    (clear-update-eval-acontext ac :instance (mo "for range indexable" 
    :av "index" (aget i "index") 
    :av "value" (aget i "value") 
    :av "operation" (aget i "operation") 
    :av "indexable" (mo "array value" 
        :av "type" (co "array type" :av "len" (length s) 
            :av "elem type" (co "unsigned int type" :av "bit size" 8)) 
        :av "value" (map 'list #'char-code s))))
)
; Наконец, рассмотрим случай для массива
(aspect "opsem" :context ac :type "for range indexable" :instance i :stage "array type" 
    :value arr :do 
    (clear-update-eval-acontext ac :stage "evaluating" :av "now" 0 :av "left" (copy-cells (aget arr "value")))
)
; Выполняет итерацию цикла: присваивает значения на текущем шаге, и запускает тело цикла
(aspect "opsem" :context ac :type "for range indexable" :instance i :stage "evaluating" 
    :ap ac "left" left :av ac "now" k :agent a :do 
    (aset a "variable cell" (aget i "index") k)
    (aset a "variable cell" (aget i "value") (car left))
    (update-push-acontext ac :av "now" (1+ k) :av "left" (cdr left))
    (clear-update-eval-acontext ac :instance (aget i "body"))
)

;; for range map
; Вычисляем выражение, которое должно в итоге дать карту
(aspect "opsem" :context ac :type "for range map" :instance i :stage nil :do 
    (update-push-acontext ac :stage "save")
    (clear-update-eval-acontext ac :instance (aget i "map") :aspect "opsem::rvalue")
)
; Сохраняем затеняемые значения переменных, переходим к итерациям цикла
(aspect "opsem" :context ac :type "for range map" :instance i :stage "save" 
    :value m :ap m "entry" mv :p (attributes mv) ks :p nil vs :do 
    (dolist (k (reverse ks)) (setq vs (cons (aget mv k) vs)))  ; cоздаем список значений
    ; Переходим к итерациям цикла
    (clear-update-eval-acontext ac :stage "evaluating" :av "keys" ks :av "values" (copy-cells vs))
)
; Выполняет итерацию цикла: присваивает значения на текущем шаге, и запускает тело цикла
(aspect "opsem" :context ac :type "for range map" :instance i :stage "evaluating" 
    :ap ac "keys" ks :ap ac "values" vs :agent a :do 
    (aset a "variable cell" (aget i "key") (car ks))
    (aset a "variable cell" (aget i "values") (car vs))
    (update-push-acontext ac :av "keys" (cdr ks) :av "values" (cdr vs))
    (clear-update-eval-acontext ac :instance (aget i "body"))
)

;; for range int
; Вычисляет количество итераций
(aspect "opsem" :context ac :type "for range int" :instance i :stage nil :do 
    (update-push-acontext ac :stage "start")
    (clear-update-eval-acontext ac :instance (aget i "max") :aspect "opsem::rvalue")
)
; Запускает итерации цикла
(aspect "opsem" :context ac :type "for range int" :instance i :stage "start" 
    :value m :do 
    (clear-update-eval-acontext ac :stage "evaluating" :av "max" m :av "now" 0)
)
; Выполняет итерацию цикла: присваивает новое значение, запускает тело цикла
(aspect "opsem" :context ac :type "for range int" :instance i :stage "evaluating" 
    :ap ac "max" m :av ac "now" k :agent a :v (< k m) T :do 
    (aset a "variable cell" (aget i "value") k)
    (update-push-acontext ac :av "max" m :av "now" (1+ k))
    (clear-update-eval-acontext ac :instance (aget i "body"))
)


;; return statement
; Проверяет, есть ли возвращаемые значения, и вычисляет первое из них
(aspect "opsem" :context ac :type "return stmt" :instance i :stage nil 
    :ap ac 1 left :do 
    (update-push-acontext ac :stage "exiting before function")
    (match :v (null left) T :exit 
        (update-push-acontext ac :stage "evaluating" :av "left" (cdr left))
        (clear-update-eval-acontext ac :instance (car left) :aspect "opsem::rvalue"))
)
; Вычисляет очередное возвращаемое значение
(aspect "opsem" :context ac :type "return stmt" :instance i :stage "evaluating" 
    :value v :ap ac "left" left :ap ac "done" d :do 
    (match :v (null left) T :do (reverse d) 
    :exit (update-push-acontext ac :av "left" (cdr left) :av "done" (cons v d))
          (clear-update-eval-acontext ac :instance (car left) :aspect "opsem::rvalue"))
)
; Выходит из всех конструкций языка, пока не встретит функцию. Результат возвращает
(aspect "opsem" :context ac :type "return stmt" :instance i :stage "exiting before function" 
    :value d :p (pop-acontext ac) ac1 :p (aget ac1 "instance") i1 :do 
    ; если встретили блок, то нужно вернуть значения всем затененнным переменным
    (nmatch :v (is-instance i1 "block") T 
    :exit (push-acontext ac) (update-eval-acontext ac1 :stage "variable back"))
    ; если встретили функцию, то возвращаем значение
    ; т.к. функция находилась на стадии вычисления тела функции
    :v (is-instance i1 "function call") T 
    :exit d (push-acontext ac1)
    ; иначе повторяем то же самое, но уже со следующим замыканием
    :do d (eval-acontext ac)
)

;; break statement
(aspect "opsem" :context ac :type "break stmt" :instance i :stage nil 
    :ap i 1 ln :p (pop-acontext ac) ac1 :ap ac1 "instance" i1 :ap ac1 "label" ln1 :do
    ; если встречен блок, то возвращает значения всем затененным переменным
    (nmatch :v (is-instance i1 "block") T 
    :exit (push-acontext ac) (update-eval-acontext ac1 :stage "variable back")
    ; если нашлась конструкция (for, switch, select), которую нужно завершить, то завершается обработка break
    :v (and (is-instance i1 "for stmt") (or (not ln) (string= ln ln1))) :exit nil 
    :v (and (is-instance i1 "switch stmt") (or (not ln) (string= ln ln1))) :exit nil 
    ; иначе продолжается выход из конструкций языка по стеку
    :do (eval-acontext ac))
)

;; continue statement
(aspect "opsem" :context ac :type "continue stmt" :instance i :stage nil 
    :ap i 1 ln :p (pop-acontext ac) ac1 :ap ac1 "instance" i1 :ap ac1 "label" ln1 :do 
    ; если встречен блок или цикл, то возвращает значения всем затененным переменным
    (nmatch :v (is-instance i1 "block") T 
    :exit (push-acontext ac) (update-eval-acontext ac1 :stage "variable back")
    ; если нашлась конструкция, которую нужно перевести на следующий шаг, то завершается обработка continue
    :v (and (is-instance i1 "for stmt") (or (not ln) (string= ln ln1))) :exit nil 
    ; иначе продолжается выход из конструкций языка по стеку
    :do (eval-acontext ac))
)

;; goto statement
(aspect "opsem" :context ac :type "goto stmt" :instance i :stage nil 
    :ap i 1 ln :p (pop-acontext ac) ac1 :ap ac1 "instance" i1 :do 
    ; если попалось помеченное нужной меткой выражение, то запускаем его с начала
    (match :ap i1 "label" ln1 :v ln1 T :v (string= ln ln1) T 
    :do (update-eval-acontext ac1 :stage nil)
    ; если попался блок, то проверяем список всех меток, находящихся в нем
    :exit (match :v (is-instance i1 "block") T :ap i1 "label positions" lp :ap lp ln pos :do 
    ; если нужная метка найдена, то будет искать в этой инструкции (м.б. это ещё один блок)
    ; так же меняем исполнение инструкций этого блока на ту, в которой нашлась метка
    (match :v pos T :ap ac1 "statements" sts :p (nthcdr pos sts) scdr :do 
    (update-push-acontext ac1 :av "left" (cdr scdr)) 
    (update-push-acontext ac1 :instance (car scdr)) 
    (eval-acontext ac)
    ; если нужной метки в этом блоке не оказалось, то возвращаем прежние значения затененных переменных
    :exit (push-acontext ac) (update-push-acontext ac1 :stage "variable back"))
    ; если попался не блок, то пропускаем
    :exit nil))
)