#|
	Operational semantics for the Go language

    Last edit: 29/06/2026
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
; Определяет тип вычисленного выражения
(aclosure ac :attribute "opsem::rvalue" :type "conversion" :instance i :stage "conversion" 
    :value tv :ap i "type" tp :ap tv "type" vtp :do 
    (mo "typed primitive" :av "type" tp :av "value" 
    (clear-update-eval-aclosure ac :av "typed value" tv :stage (nmatch 
    ; численные типы данных конвертируются между собой
    :v (is-instance vtp "int type")     T :exit "int type" 
    :v (is-instance vtp "float type")   T :exit "float type" 
    :v (is-instance vtp "complex type") T :exit "complex type" 
    ; string, []byte тоже конвертируются между собой
    :v (is-instance vtp "string type") T :exit "string type" 
    :v (is-instance vtp "slice type")  T :exit "byte type")))
)
; Сначала обрезаем старшие биты (если нужно), получаем x
; Полученный x имеется беззнаковое представление. Если нужно, приводим к знаковому
(aclosure ac :attribute "opsem::rvalue" :type "conversion" :instance i :stage "int type" 
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
(aclosure ac :attribute "opsem::rvalue" :type "conversion" :instance i :stage "float type" 
    :ap ac "typed value" tv :ap tv "value" v :ap i "type" tp 
    :ap tp "bit size" bs :p (logand v (1- (ash 1 bs))) x :do 
    (nmatch 
    :v (is-instance tp "signed int type")   T 
    :exit (let ((p (truncate x 1))) (if (> p (ash 1 (1- bs))) (- p (ash 1 bs)) p))
    :v (is-instance tp "unsigned int type") T :exit (truncate x 1)
    :v (is-instance tp "float type")        T :exit v)
)
; Комплексные значения можно приводить только к комплексным.
; Выполним приведение отдельно вещественной и мнимых частей, как float type.
(aclosure ac :attribute "opsem::rvalue" :type "conversion" :instance i :stage "complex type" 
    :ap ac "typed value" tv :ap tv "value" v
    :p (mo "float type" :av "bit size" (aget i "type" "bit size")) ctp 
    :p (mo "float type" :av "bit size" (aget tv "type" "bit size")) vtp :do 
    (update-push-aclosure ac :stage "complex eval im" :av "conversion type" ctp 
        :av "im" (mo "typed primitive" :av "type" vtp :av "value" (imagpart v)))
    (clear-update-eval-aclosure ac :instance (mo "conversion" :av "type" ctp 
        :av "value" (mo "typed primitive" :av "type" vtp :av "value" (realpart v))))
)
; Сохраняет вычисленную вещественную часть. Отправляет вычислять мнимую часть
(aclosure ac :attribute "opsem::rvalue" :type "conversion" :stage "complex eval im" 
    :ap ac "im" im :ap ac "conversion type" ctp :value re :do 
    (update-push-aclosure ac :stage "complex return" :av "re" re)
    (clear-update-eval-aclosure ac :instance (mo "conversion" :av "type" ctp :av "value" im))
)
; Возвращает комплексное число по вычисленным значениям составляющих
(aclosure ac :attribute "opsem::rvalue" :type "conversion" :stage "complex return" 
    :ap ac "re" re :value im :do (complex (aget re "value") (aget im "value"))
)
; Нетривиальный случай только для среза битов
(aclosure ac :attribute "opsem::rvalue" :type "conversion" :instance i :stage "string type" 
    :ap ac "typed value" tv :ap tv "value" v :ap i "type" tp :do 
    (nmatch 
    :v (is-instance tp "string type") T :exit v 
    :do (mapcar #'char-code (coerce v 'list)))
)
; Сначала из среза вытаскивает значения, на которые он ссылкается
; Затем превращет полученный список в строку
(aclosure ac :attribute "opsem::rvalue" :type "conversion" :instance i :stage "byte type" 
    :ap ac "typed value" tv :ap tv "value" sv :ap i "type" tp :ap sv "offset" ofs :do 
    (let ((lst nil) (cs (aget sv "array" "elements"))) (dotimes (k ofs) (setf cs (cdr cs))) ; cs - элементы, на которые указывает срез (справа могут быть лишние)
    (dotimes (k (aget sv "length") (reverse lst)) (setf lst (cons (aget (car cs) "value") lst)) (setf cs (cdr cs))))
    (match :v (is-instance tp "string type") nil :do sv 
    :exit (coerce (mapcar #'code-char lst) 'string))
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
    (clear-update-eval-aclosure ac :instance (aget i "receiver") :attribute "opsem::rvalue")
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
(aclosure ac :attribute "opsem::rvalue" :type "index expr" :stage "return value" 
    :value index :ap ac "indexable" indl :ap indl "type" it :do 
    (nmatch :v it "array type"  :exit (aget (nth index (aget indl "elements")) "value")
            :v it "slice type"  :exit (aget (nth (+ (aget indl "offset") index) 
                (aget indl "array" "elements")) "value")
            :v it "map type"    :exit (aget (aget indl "entries" index) "value")
            :v it "string type" :exit (char (aget indl "value") index))
)

; Для lvalue всё вычисляется абсолютно так же
(aclosure ac :attribute "opsem::lvalue" :type "indexable expr" :instance i :stage nil :do 
    (update-push-aclosure ac :stage "eval index")
    (clear-update-eval-aclosure ac :instance (aget i "indexable") :attribute "opsem::rvalue")
)
(aclosure ac :attribute "opsem::lvalue" :type "index expr" :instance i :stage "eval index" 
    :value indl :do 
    (update-push-aclosure ac :stage "return value" :av "indexable" indl)
    (clear-update-eval-aclosure ac :instance (aget i "index") :attribute "opsem::rvalue")
)
; Строки являются неизменяемыми
(aclosure ac :attribute "opsem::lvalue" :type "index expr" :stage "return value" 
    :value index :ap ac "indexable" indl :ap indl "type" it :do 
    (nmatch :v it "array type" :exit (nth index (aget indl "elements")) 
            :v it "slice type" :exit (nth (+ offset index) (aget indl "array" "elements"))
            :v it "map type"   :exit (aget indl "entries" index))
)

;; slice expr
; Сперва вычисляем атрибуты - выражения: slice, low, high, max
(aclosure ac :attribute "opsem::rvalue" :type "slice expr" :instance i :stage nil :do 
    (update-push-aclosure ac :stage "eval low")
    (clear-update-eval-aclosure ac :instance (aget i "sequence"))
)
(aclosure ac :attribute "opsem::rvalue" :type "slice expr" :instance i :stage "eval low" 
    :value s :do 
    (update-push-aclosure ac :stage "eval high" :av "sequence" s)
    (clear-update-eval-aclosure ac :instance (aget i "low"))
)
(aclosure ac :attribute "opsem::rvalue" :type "slice expr" :instance i :stage "eval high" 
    :ap ac "sequence" s :value low :do
    (update-push-aclosure ac :stage "eval max" :av "sequence" s :av "low" (if low low 0))
    (clear-update-eval-aclosure ac :instance (aget i "high"))
)
(aclosure ac :attribute "opsem::rvalue" :type "slice expr" :instance i :stage "eval max" 
    :ap ac "sequence" s :ap ac "low" low :value high :do 
    (update-push-aclosure ac :stage "build value" :av "sequence" s :av "low" low :av "high" high)
    (clear-update-eval-aclosure ac :instance (aget i "max"))
)
; Определяем тип последовательности, от которой нужно взять срез
(aclosure ac :attribute "opsem::rvalue" :type "slice expr" :stage "build value" 
    :ap ac "sequence" s :ap ac "low" low :ap ac "high" high :value cap :ap s "type" st :do 
    (clear-update-eval-aclosure ac :stage (otype st) 
        :av "sequence" s :av "low" low :av "high" high :av "cap" cap)
)
; Если срез нужно взять от массива
(aclosure ac :attribute "opsem::rvalue" :type "slice expr" :stage "array type" 
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
(aclosure ac :attribute "opsem::rvalue" :type "slice expr" :stage "pointer type" 
    :ap ac "sequence" s :ap ac "low" low :ap ac "high" high :ap ac "cap" cap :do 
    (clear-update-eval-aclosure ac :stage "array type" :av "sequence" (aget s "value"))
)
; Если срез нужно взять от среза
(aclosure ac :attribute "opsem::rvalue" :type "slice expr" :stage "slice type" 
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
(aclosure ac :attribute "opsem::rvalue" :type "slice expr" :stage "string type" 
    :p (aget ac "sequence" "value") s :ap ac "low" low :ap ac "high" high :do 
    (if (not high) (aset high (length s)))
    (subseq s low high)
)

;; function call
; Отправляет вычислять функцию, получаем значение функции
(aclosure ac :attribute "opsem::rvalue" :type "function call" :instance i :stage nil :do 
    (update-push-aclosure ac :stage "eval arguments")
    (clear-update-eval-aclosure ac :instance (aget i "function"))
)
; Отправляет вычислять значения параметров
(aclosure ac :attribute "opsem::rvalue" :type "function call" :instance i :stage "eval arguments" 
    :value f :ap i "arguments" as :do 
    (update-push-aclosure ac :stage "copy parameters" :av "function" f)
    (match :v (null as) T :do nil 
    :exit (update-push-aclosure ac :stage "evaluating" :av "arguments" nil :av "left" (cdr as))
          (clear-update-eval-aclosure ac :instance (car as)))
)
; Вычисляет значение очередного параметра
(aclosure ac :attribute "opsem::rvalue" :type "function call" :stage "evaluating" 
    :ap ac "arguments" as :ap ac "left" left :value v :p (cons v as) nas :do 
    (match :v (null left) T :do (reverse nas) 
    :exit (update-push-aclosure ac :av "arguments" (cdr as) :av "left" (cdr left))
          (clear-update-eval-aclosure ac :instance (car as)))
)
; Сохраняет старые значения параметров
; Если результат функции именованный, то отправляет сохранять для них старые ячейки, и вычислять значения по умолчанию
(aclosure ac :attribute "opsem::rvalue" :type "function call" :stage "copy parameters" 
    :ap ac "function" f :ap f "signature" sgn :ap sgn "result" r :value as :agent a :p nil dcs :do 
    (let ((args as)) (dolist (p (aget sgn "parameters")) 
        ; сохранить старую ячейку памяти
        (setf dcs (cons (aget a "variable cell" (aget p "name")) dcs))
        ; установить новое значение для затеняющего (наверное) параметра
        (aset a "variable cell" (aget p "name") (mo "cell" :av "type" (aget p "type") :av "value" (car args)))
        (setf args (cdr args))))
    (update-push-aclosure ac :stage "copy closure" :av "function" f)
    (match :v (null r) nil :v (is-instance (car r) "param decl") T :do  ; если результат функции именованный
        (update-push-aclosure ac :stage "copying result" :av "left" r :av "done" dcs)
        (clear-update-eval-aclosure ac :instance (aget (car r) "type") :attribute "default value by type")
    :exit dcs)
)
; Сохраняет старые ячейки для именованного результата функции, и вычисляет для них значения по умолчанию
(aclosure ac :attribute "opsem::rvalue" :type "function call" :stage "copying result" 
    :ap ac "left" l :ap ac "done" done :value v :agent a :ap (car l) "name" n 
    :p (cons (aget a "variable cell" n) done) nd :do 
    (aset a "variable cell" n (mo "cell" :av "type" (aget (car l) "type") :av "value" v))
    (match :v (null l) T :do nd 
    :exit (update-push-aclosure ac :av "left" (cdr "left") :av "done" nd)
          (clear-update-eval-aclosure ac :instance (aget (car l) "type") :attribute "default value by type"))
)
; Сохраняет старые значения переменных из замыкания функции
(aclosure ac :attribute "opsem::rvalue" :type "function call" :stage "copy closure" 
    :ap ac "function" f :value dcs :ap f "closure" cl :agent a :do 
    (dolist (n (attributes cl)) (setf dcs (cons (aget cl n) dcs)) 
        (setf a "variable cell" n (mo "cell" :av "type" (aget cl n "type") :av "value" (aget cl n "value"))))
    (update-push-aclosure ac :stage "variable back" :av "function" f :av "cells" (reverse dcs))
    (clear-update-eval-aclosure ac :instance (aget f "body"))
)
; Возвращаем прежние значения функции
(aclosure ac :attribute "opsem::rvalue" :type "function call" :stage "variable back" 
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
(aclosure ac :attribute "opsem::rvalue" :type "method call" :instance i :stage nil :do 
    (update-push-aclosure ac :stage "eval arguments")
    (clear-update-eval-aclosure ac :instance (aget i "receiver"))
)
; Преобразуем метод в функцию
(aclosure ac :attribute "opsem::rvalue" :type "method call" :instance i :stage "to function" 
    :value rec :do 
    (update-push-aclosure ac :stage "eval call")
    (clear-update-eval-aclosure ac :instance (mo "method expr" 
        :av "receiver type" (aget rec "type") :av "name" (aget i "method")))
)
; Исполняем вызов функции на преобразованной из метода
(aclosure ac :attribute "opsem::rvalue" :type "method call" :instance i :stage "eval call" :value f :do 
    (clear-update-eval-aclosure ac :instance (mo "function call" 
        :av "function" f :av "arguments" (aget i "arguments")))
)

;;; Unary expressions
(aclosure ac :attribute "opsem::rvalue" :type "unary expression" :instance i :stage nil :do 
    (update-push-aclosure ac :stage "apply")
    (clear-update-eval-aclosure ac :instance (aget i 1))
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
(aclosure ac :attribute "opsem::rvalue" :type "+1" :stage "apply" :value v :do v)

;; unary minus
; Вычисляем значение операции и приводим результат к нужному типу
(aclosure ac :attribute "opsem::rvalue" :type "-1" :stage "apply" :value pr 
    :ap pr "value" v :ap pr "type" tp :do (convert-int-to-type tp (- v))
)

;; bitwise not
(aclosure ac :attribute "opsem::rvalue" :type "^1" :stage "apply" :value pr 
    :ap pr "value" v :ap pr "type" tp :do (convert-int-to-type tp (lognot v))
)

;; logical not
(aclosure ac :attribute "opsem::rvalue" :type "!1" :stage "apply" :value v :do 
    (mo "typed primitive" :av "type" (aget v "type") :av "value" (not (aget v "value")))
)

;; pointer dereference
; Разыменование применимо только к ячейкам памяти cell
(aclosure ac :attribute "opsem::rvalue" :type "*1" :stage "apply" 
    :value tv :ap tv "value" v :do  ; tp - pointer type; v - cell
    (mo "typed primitive" :av "type" (aget tv "type") :av "value" (aget v "value"))
)

(aclosure ac :attribute "opsem::lvalue" :type "*1" :instance i :stage nil :do 
    (update-push-aclosure ac :stage "apply")
    (clear-update-eval-aclosure ac :instance (aget i 1))
)
(aclosure ac :attribute "opsem::lvalue" :type "*1" :stage "apply" :value v :do (aget v "value"))

;; address of
(aclosure ac :attribute "opsem::rvalue" :type "&1" :instance i :stage "apply" 
    :value tv :ap tv "type" tp :ap tv "value" v :do 
    (mo "typed primitive" :av "type" (co "pointer type" :av "type" tp) 
        :av "value" (mo "cell" :av "value" v :av "type" tp))
)

;;; Binary expressions
(aclosure ac :attribute "opsem::rvalue" :type "binary expression" :instance i :stage nil :do 
    (update-push-aclosure ac :stage "apply 1")
    (clear-update-eval-aclosure ac :instance (aget i 1))
)

;; logical OR
(aclosure ac :attribute "opsem::rvalue" :type "1||2" :instance i :stage "apply 1" :value v :do 
    (match :v (aget v "value") T 
    :do (mo "typed primitive" :av "type" (co "bool type") :av "value" T) 
    :exit (update-push-aclosure ac :stage "apply 2")
          (clear-update-eval-aclosure ac :instance (aget i 2)))
)
(aclosure ac :attribute "opsem::rvalue" :type "1||2" :stage "apply 2" :value v :do 
    (mo "typed primitive" :av "type" (co "bool type") :av "value" (aget v "value"))
)

;; logical AND
(aclosure ac :attribute "opsem::rvalue" :type "1&&2" :instance i :stage "apply 1" :value v :do 
    (match :v (aget v "value") nil 
    :do (mo "typed primitive" :av "type" (co "bool type") :av "value" nil) 
    :exit (update-push-aclosure ac :stage "apply 2")
          (clear-update-eval-aclosure ac :instance (aget i 2)))
)
(aclosure ac :attribute "opsem::rvalue" :type "1&&2" :stage "apply 2" :value v :do
    (mo "typed primitive" :av "type" (co "bool type") :av "value" (aget v "value"))
)

;; addition
(aclosure ac :attribute "opsem::rvalue" :type "1+2" :instance i :stage "apply 1" :value v :do 
    (update-push-aclosure ac :stage "apply 2" :av 1 v)
    (clear-update-eval-aclosure ac :instance (aget i 2))
)
(aclosure ac :attribute "opsem::rvalue" :type "1+2" :stage "apply 2" 
    :ap ac 1 f :ap f "type" tp :ap f "value" fv :value s :ap s "value" sv :do 
    (convert-int-to-type tp (+ fv sv))
)

;; substraction
(aclosure ac :attribute "opsem::rvalue" :type "1-2" :instance i :stage "apply 1" :value v :do 
    (update-push-aclosure ac :stage "apply 2" :av 1 v)
    (clear-update-eval-aclosure ac :instance (aget i 2))
)
(aclosure ac :attribute "opsem::rvalue" :type "1-2" :stage "apply 2" 
    :ap ac 1 f :ap f "type" tp :ap f "value" fv :value s :ap s "value" sv :do 
    (convert-int-to-type tp (- fv sv))
)

;; multiplication
(aclosure ac :attribute "opsem::rvalue" :type "1*2" :instance i :stage "apply 1" :value v :do 
    (update-push-aclosure ac :stage "apply 2" :av 1 v)
    (clear-update-eval-aclosure ac :instance (aget i 2))
)
(aclosure ac :attribute "opsem::rvalue" :type "1*2" :stage "apply 2" 
    :ap ac 1 f :ap f "type" tp :ap f "value" fv :value s :ap s "value" sv :do 
    (convert-int-to-type tp (* fv sv))
)

;; division
(aclosure ac :attribute "opsem::rvalue" :type "1/2" :instance i :stage "apply 1" :value v :do 
    (update-push-aclosure ac :stage "apply 2" :av 1 v)
    (clear-update-eval-aclosure ac :instance (aget i 2))
)
(aclosure ac :attribute "opsem::rvalue" :type "1/2" :stage "apply 2" 
    :ap ac 1 f :ap f "type" tp :ap f "value" fv :value s :ap s "value" sv :do 
    (convert-int-to-type tp (/ fv sv))
)

;; remainder
(aclosure ac :attribute "opsem::rvalue" :type "1%2" :instance i :stage "apply 1" :value v :do 
    (update-push-aclosure ac :stage "apply 2" :av 1 v)
    (clear-update-eval-aclosure ac :instance (aget i 2))
)
; Есть особый случай для MinInt % -1, но считаем программу корректно написанной
(aclosure ac :attribute "opsem::rvalue" :type "1%2" :stage "apply 2" 
    :ap ac 1 f :ap f "type" tp :ap f "value" fv :value s :ap s "value" sv :do 
    (convert-int-to-type tp (rem fv sv))
)

;; left shift
(aclosure ac :attribute "opsem::rvalue" :type "1<<2" :instance i :stage "apply 1" :value v :do 
    (update-push-aclosure ac :stage "apply 2" :av 1 v)
    (clear-update-eval-aclosure ac :instance (aget i 2))
)
(aclosure ac :attribute "opsem::rvalue" :type "1<<2" :stage "apply 2" 
    :ap ac 1 f :ap f "type" tp :ap f "value" fv :value s :ap s "value" sv :do 
    (convert-int-to-type tp (ash fv sv))
)

;; right shift
(aclosure ac :attribute "opsem::rvalue" :type "1>>2" :instance i :stage "apply 1" :value v :do 
    (update-push-aclosure ac :stage "apply 2" :av 1 v)
    (clear-update-eval-aclosure ac :instance (aget i 2))
)
(aclosure ac :attribute "opsem::rvalue" :type "1>>2" :stage "apply 2" 
    :ap ac 1 f :ap f "type" tp :ap f "value" fv :value s :ap s "value" sv :do 
    (convert-int-to-type tp (ash fv (- sv)))
)

;; bitwise AND
(aclosure ac :attribute "opsem::rvalue" :type "1&2" :instance i :stage "apply 1" :value v :do 
    (update-push-aclosure ac :stage "apply 2" :av 1 v)
    (clear-update-eval-aclosure ac :instance (aget i 2))
)
(aclosure ac :attribute "opsem::rvalue" :type "1&2" :stage "apply 2" 
    :ap ac 1 f :ap f "type" tp :ap f "value" fv :value s :ap s "value" sv :do 
    (convert-int-to-type tp (logand fv sv))
)

;; bitwise AND NOT
(aclosure ac :attribute "opsem::rvalue" :type "1&^2" :instance i :stage "apply 1" :value v :do 
    (update-push-aclosure ac :stage "apply 2" :av 1 v)
    (clear-update-eval-aclosure ac :instance (aget i 2))
)
(aclosure ac :attribute "opsem::rvalue" :type "1&^2" :stage "apply 2" 
    :ap ac 1 f :ap f "type" tp :ap f "value" fv :value s :ap s "value" sv :do 
    (convert-int-to-type tp (logand fv (lognot sv)))
)

;; bitwise OR
(aclosure ac :attribute "opsem::rvalue" :type "1|2" :instance i :stage "apply 1" :value v :do 
    (update-push-aclosure ac :stage "apply 2" :av 1 v)
    (clear-update-eval-aclosure ac :instance (aget i 2))
)
(aclosure ac :attribute "opsem::rvalue" :type "1|2" :stage "apply 2" 
    :ap ac 1 f :ap f "type" tp :ap f "value" fv :value s :ap s "value" sv :do 
    (convert-int-to-type tp (logior fv sv))
)

;; bitwise XOR
(aclosure ac :attribute "opsem::rvalue" :type "1^2" :instance i :stage "apply 1" :value v :do 
    (update-push-aclosure ac :stage "apply 2" :av 1 v)
    (clear-update-eval-aclosure ac :instance (aget i 2))
)
(aclosure ac :attribute "opsem::rvalue" :type "1^2" :stage "apply 2" 
    :ap ac 1 f :ap f "type" tp :ap f "value" fv :value s :ap s "value" sv :do 
    (convert-int-to-type tp (logxor fv sv))
)

;;; Relation expressions
(aclosure ac :attribute "opsem::rvalue" :type "1==2" :instance i :stage "apply 1" :value v :do 
    (update-push-aclosure ac :stage "apply 2" :av 1 v)
    (clear-update-eval-aclosure ac :instance (aget i 2))
)
(aclosure ac :attribute "opsem::rvalue" :type "1==2" :stage "apply 2" 
    :ap ac 1 f :ap f "type" tp :ap f "value" fv :value s :ap s "value" sv :do 
    (convert-int-to-type tp (= fv sv))
)

(aclosure ac :attribute "opsem::rvalue" :type "1!=2" :instance i :stage "apply 1" :value v :do 
    (update-push-aclosure ac :stage "apply 2" :av 1 v)
    (clear-update-eval-aclosure ac :instance (aget i 2))
)
(aclosure ac :attribute "opsem::rvalue" :type "1!=2" :stage "apply 2" 
    :ap ac 1 f :ap f "type" tp :ap f "value" fv :value s :ap s "value" sv :do 
    (convert-int-to-type tp (not (= fv sv)))
)

(aclosure ac :attribute "opsem::rvalue" :type "1<2" :instance i :stage "apply 1" :value v :do 
    (update-push-aclosure ac :stage "apply 2" :av 1 v)
    (clear-update-eval-aclosure ac :instance (aget i 2))
)
(aclosure ac :attribute "opsem::rvalue" :type "1<2" :stage "apply 2" 
    :ap ac 1 f :ap f "type" tp :ap f "value" fv :value s :ap s "value" sv :do 
    (convert-int-to-type tp (< fv sv))
)

(aclosure ac :attribute "opsem::rvalue" :type "1<=2" :instance i :stage "apply 1" :value v :do 
    (update-push-aclosure ac :stage "apply 2" :av 1 v)
    (clear-update-eval-aclosure ac :instance (aget i 2))
)
(aclosure ac :attribute "opsem::rvalue" :type "1<=2" :stage "apply 2" 
    :ap ac 1 f :ap f "type" tp :ap f "value" fv :value s :ap s "value" sv :do 
    (convert-int-to-type tp (<= fv sv))
)

(aclosure ac :attribute "opsem::rvalue" :type "1>2" :instance i :stage "apply 1" :value v :do 
    (update-push-aclosure ac :stage "apply 2" :av 1 v)
    (clear-update-eval-aclosure ac :instance (aget i 2))
)
(aclosure ac :attribute "opsem::rvalue" :type "1>2" :stage "apply 2" 
    :ap ac 1 f :ap f "type" tp :ap f "value" fv :value s :ap s "value" sv :do 
    (convert-int-to-type tp (> fv sv))
)

(aclosure ac :attribute "opsem::rvalue" :type "1>=2" :instance i :stage "apply 1" :value v :do 
    (update-push-aclosure ac :stage "apply 2" :av 1 v)
    (clear-update-eval-aclosure ac :instance (aget i 2))
)
(aclosure ac :attribute "opsem::rvalue" :type "1>=2" :stage "apply 2" 
    :ap ac 1 f :ap f "type" tp :ap f "value" fv :value s :ap s "value" sv :do 
    (convert-int-to-type tp (>= fv sv))
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
    (clear-update-eval-aclosure ac :stage "evaluating statement" :av "left" sts :av "statements" sts)
)
; Вычисляет очередной оператор блока (очередную инструкцию блока).
; Для навигации, в том числе для меток, передает номер инструкции в блоке
(aclosure ac :attribute "opsem" :type "block" :instance i :stage "evaluating statement" 
    :ap ac "left" left :v (null left) nil :ap ac "statements" sts :do 
    (update-push-aclosure ac :av "left" (cdr left) :av "statements" sts)
    (clear-update-eval-aclosure ac :instance (car left) :av "block" i)
)
; Восстанавливает старые ячейки памяти декларированным в блоке (важны только затенённые) переменным.
(aclosure ac :attribute "opsem" :type "block" :instance i :stage "variable back" :do 
    (dolist (item (aget i "decl variables")) (aset a "variable cell" item (aget item "variable cells")))
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
    :ap ac "block" b :ap i "names" ns :ap i "values" vs :ap i "types" ts :do 
    (match :v (null vs) T 
    :do (update-push-aclosure ac :stage "declarating defaults" 
                                 :av "names" ns :av "types" (cdr ts) :av "block" b)
        (clear-update-eval-aclosure ac :attribute "default value by type" :instance (car ts))
    :exit (update-push-aclosure ac :stage "evaluating values" 
          :av "names" ns :av "types" ts :av "values" (cdr vs) :av "block" b)
          (clear-update-eval-aclosure ac :instance (car vs)))
)
; Декларируем очередную переменную по значению по умолчанию соответсвующего типа.
(aclosure ac :attribute "opsem" :type "var decl" :instance i :stage "declarating defaults" 
    :ap ac "names" ns :ap ac "types" ts :ap ac "block" b :value v :agent a :do 
    (aset b "variable cells" (car ns) (aget a "variable cell" (car ns)))  ; сохраняем в блок информацию о старой ячейке переменной
    (aset a "variable cell" (car ns) (mo "cell" :av "value" v 
                                                :av "type" (co "pointer type" :av "type" (car ts))))
    (match :v (null ts) nil :do 
    (update-push-aclosure ac :av "names" (cdr ns) :av "types" (cdr ts) :av "block" b)
    (clear-update-eval-aclosure ac :attribute "default value by type" :instance (car ts)))
)
; Декларируем очередную переменную по явно заданному значению.
(aclosure ac :attribute "opsem" :type "var decl" :instance i :stage "evaluating values" 
    :ap ac "names" ns :ap ac "values" vs :ap ac "types" ts :ap ac "block" b :value v :agent a :do 
    (aset b "variable cells" (car ns) (aget a "variable cell" (car ns)))  ; сохраняем в блок информацию о старой ячейке переменной
    (aset a "variable cell" (car ns) (mo "cell" :av "value" v 
                                                :av "type" (co "pointer type" :av "type" (car ts))))
    (match :v (null vs) nil :do 
    (update-push-aclosure ac :av "names" (cdr ns) :av "types" (cdr ts) :av "values" (cdr vs) :av "block" b)
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
;;; Statements
;;; ================================================

;; label
(aclosure ac :attribute "opsem" :type "label" :instance i :do 
    (clear-update-eval-aclosure ac :instance (aget i "statement") 
    :av "block" (aget ac "block") :av "label" (aget i "name"))
)

;; empty statement
(aclosure ac :attribute "opsem" :type "empty stmt")

;; increment statement
(aclosure ac :attribute "opsem" :type "1++ stmt" :instance i :stage nil :do 
    (update-push-aclosure ac :stage "apply")
    (clear-update-eval-aclosure ac :attribute "opsem::lvalue" :instance (aget i 1))
)
; Здесь v должно иметь тип "cell", как любое lvalue значение в модели
(aclosure ac :attribute "opsem" :type "1++ stmt" :instance i :stage "apply" :value v :do 
    (aset v "value" (convert-int-to-type (aget i "type") (1+ (aget v "value"))))
)

;; decrement statement
(aclosure ac :attribute "opsem" :type "1-- stmt" :instance i :stage nil :do 
    (update-push-aclosure ac :stage "apply")
    (clear-update-eval-aclosure ac :attribute "opsem::lvalue" :instance (aget i 1))
)
; Здесь v должно иметь тип "cell", как любое lvalue значение в модели
(aclosure ac :attribute "opsem" :type "1-- stmt" :instance i :stage "apply" :value v :do 
    (aset v "value" (convert-int-to-type (aget i "type") (1- (aget v "value"))))
)

;;; Assignment statements
; Вычисляет левый аргумент в позиции lvalue. Он должен иметь тип "cell"
(aclosure ac :attribute "opsem" :type "assignment stmt" :instance i :stage nil :do 
    (update-push-aclosure ac :stage "eval 2")
    (clear-update-eval-aclosure ac :attribute "opsem::lvalue" :instance (aget i 1))
)
; Вычисляет правый аргумент в позиции rvalue
(aclosure ac :attribute "opsem" :type "assignment stmt" :instance i :stage "eval 2" :value v :do 
    (update-push-aclosure ac :stage "apply" :ac 1 v)
    (clear-update-eval-aclosure ac :attribute "opsem::rvalue" :instance (aget i 2))
)

(aclosure ac :attribute "opsem" :type "1=2" :stage "apply" :ap ac 1 f :value s :do 
    (aset f "value" s)  ; Присваивать допускается только значения того же типа
)

(aclosure ac :attribute "opsem" :type "1+=2" :stage "apply" :ap ac 1 f :value s :do 
    (aset f "value" (convert-int-to-type (aget f "type") (+ (aget f "value") (aget s "value"))))
)

(aclosure ac :attribute "opsem" :type "1-=2" :stage "apply" :ap ac 1 f :value s :do 
    (aset f "value" (convert-int-to-type (aget f "type") (- (aget f "value") (aget s "value"))))
)

(aclosure ac :attribute "opsem" :type "1*=2" :stage "apply" :ap ac 1 f :value s :do 
    (aset f "value" (convert-int-to-type (aget f "type") (* (aget f "value") (aget s "value"))))
)

(aclosure ac :attribute "opsem" :type "1/=2" :stage "apply" :ap ac 1 f :value s :do 
    (aset f "value" (convert-int-to-type (aget f "type") (/ (aget f "value") (aget s "value"))))
)

(aclosure ac :attribute "opsem" :type "1<<=2" :stage "apply" :ap ac 1 f :value s :do 
    (aset f "value" (convert-int-to-type (aget f "type") (ash (aget f "value") (aget s "value"))))
)

(aclosure ac :attribute "opsem" :type "1>>=2" :stage "apply" :ap ac 1 f :value s :do 
    (aset f "value" (convert-int-to-type (aget f "type") (ash (aget f "value") (- (aget s "value")))))
)

(aclosure ac :attribute "opsem" :type "1^=2" :stage "apply" :ap ac 1 f :value s :do 
    (aset f "value" (convert-int-to-type (aget f "type") (logxor (aget f "value") (aget s "value"))))
)

(aclosure ac :attribute "opsem" :type "1|=2" :stage "apply" :ap ac 1 f :value s :do 
    (aset f "value" (convert-int-to-type (aget f "type") (logior (aget f "value") (aget s "value"))))
)

(aclosure ac :attribute "opsem" :type "1%=2" :stage "apply" :ap ac 1 f :value s :do 
    (aset f "value" (convert-int-to-type (aget f "type") (rem (aget f "value") (aget s "value"))))
)

(aclosure ac :attribute "opsem" :type "1&=2" :stage "apply" :ap ac 1 f :value s :do 
    (aset f "value" (convert-int-to-type (aget f "type") (logand (aget f "value") (aget s "value"))))
)

(aclosure ac :attribute "opsem" :type "1&^=2" :stage "apply" :ap ac 1 f :value s :do 
    (aset f "value" (convert-int-to-type (aget f "type") (logand (aget f "value") (lognot (aget s "value")))))
)

;; if statement
(aclosure ac :attribute "opsem" :type "if stmt" :instance i :stage nil :do 
    (update-push-aclosure ac :stage "apply")
    (clear-update-eval-aclosure ac :instance (aget i "condition") :attribute "opsem::rvalue")
)
(aclosure ac :attribute "opsem" :type "if stmt" :instance i :stage "apply" :value c :do 
    (clear-update-eval-aclosure ac :instance (aget i (if c "then" "else")))
)

;;; switch statement

;; expression switch statement
; Сначала вычисляем выражение, которое будем сравнивать
(aclosure ac :attribute "opsem" :type "expr switch stmt" :instance i :stage nil :do 
    (update-push-aclosure ac :stage "apply cont" :av "block" (aget ac "block"))
    (clear-update-eval-aclosure ac :instance (aget i "controlled") :attribute "opsem::rvalue")
)
; Вычисляем первую ветку case, запускаем вычисление следующих веток
(aclosure ac :attribute "opsem" :type "expr switch stmt" :instance i :stage "apply cont" :value cont 
    :ap i "cases" cs :v (null cs) nil :ap ac "block" b :do 
    (match :v cont nil :p cont T :do  ; синтаксический сахар языка Go
        (update-push-aclosure ac :stage "evaluating cases" :av "cont" cont :av "left" (cdr cs) :av "block" b)
        (clear-update-eval-aclosure ac :instance (car cs) :av "cont" cont) :av "block" b)
)
; Проверяем, остались ли ещё ветки. Проверяем, смогла ли сработать последняя ветка :value = T, или нет:
; expr case clause возвращает, нашлось ли в нём подходящее значение
(aclosure ac :attribute "opsem" :type "expr switch stmt" :instance i :stage "evaluating cases" 
    :ap ac "cont" cont :ap ac "left" left :v (null left) nil :value v :v v nil :ap ac "block" b :do 
    (update-push-aclosure ac :av "cont" cont :av "left" (cdr left) :av "block" b)
    (clear-update-eval-aclosure ac :instance (car left) :av "cont" cont :av "block" b)
)
; Вычисляем значение первого случая в ветке. Запускаем вычисление последующих значений ветки
(aclosure ac :attribute "opsem" :type "expr case clause" :instance i :stage nil 
    :ap ac "cont" cont :ap i "cases" cs :ap ac "block" b :do 
    (match :v (null cs) T :do nil :exit 
        (update-push-aclosure ac :stage "evaluating" :av "cont" cont :av "left" (cdr cs) :av "block" b)
        (clear-update-eval-aclosure ac :instance (mo "1==2" :av 1 cont :av 2 (car cs)) 
                                       :attribute "opsem::rvalue") :av "block" b)
)
; Проверяем, смог ли сработать предыдущий случай ветки. Проверяем следующие значения
(aclosure ac :attribute "opsem" :type "expr case clause" :instance i :stage "evaluating" 
    :value v :ap ac "cont" cont :ap ac "left" left :ap ac "block" b :do 
    (match :v v nil  ; если предыдущий случай не подходит
    :do (nmatch :v (null left) T :exit nil  ; если ничего не подошло
        :v (otype (car left)) "default"  ; если дошли до ветки default (последняя из веток, если есть)
        :exit (clear-update-eval-aclosure ac :stage "evaluating body" 
                                             :av "left" (aget i "statements") :av "block" b)
        ; если остались не рассмотренные случаи
        :do (update-push-aclosure ac :av "cont" cont :av "left" (cdr cs) :av "block" b)
            (clear-update-eval-aclosure ac :instance (mo "1==2" :av 1 cont :av 2 (car cs))
                                           :attribute "opsem::rvalue") :av "block" b)
    ; если предыдущий случай подходит, то выполняем тело данной ветки
    :exit (clear-update-eval-aclosure ac :stage "evaluating body" 
                                         :av "left" (aget i "statements") :av "block" b))
)
; Выполняет тело подошедшей ветки case
(aclosure ac :attribute "opsem" :type "expr case clause" :instance i :stage "evaluating body" 
    :ap ac "left" left :ap ac "block" b :do 
    (match :v (null left) T :do T :exit 
        (update-push-aclosure ac :av "left" (cdr left) :av "block" b)
        (clear-update-eval-aclosure ac :instance (car left) :av "block" b))
)

;;; for statement

;; for condition
; Вычисляем условное выражение
(aclosure ac :attribute "opsem" :type "for condition" :instance i :stage nil :do 
    (update-push-aclosure ac :stage "apply")
    (clear-update-eval-aclosure ac :instance (aget i "condition") :attribute "opsem::rvalue")
)
; Если вычисленное значение правдиво, то выполняем тело и возвращаемся к предыдущему шагу
(aclosure ac :attribute "opsem" :type "for condition" :instance i :stage "apply" :value v :v v T :do 
    (update-push-aclosure ac :stage nil)
    (clear-update-eval-aclosure ac :instance (aget i "body"))
)

;; for clause
; Вычисляем условное выражение
(aclosure ac :attribute "opsem" :type "for clause" :instance i :stage nil :do 
    (update-push-aclosure ac :stage "apply")
    (clear-update-eval-aclosure ac :instance (aget i "condition") :attribute "opsem::rvalue")
)
; Если оно правдиво, то выполняем тело
(aclosure ac :attribute "opsem" :type "for clause" :instance i :stage "apply" :value v :v v T :do 
    (update-push-aclosure ac :stage "post")
    (clear-update-eval-aclosure ac :instance (aget i "body"))
)
; После вычисления тела, выполняем оператор шага post, и возвращаемся к вычислению условного выражения
(aclosure ac :attribute "opsem" :type "for clause" :instance i :stage "post" :do 
    (update-push-aclosure ac :stage nil)
    (clear-update-eval-aclosure ac :instance (aget i "post"))
)

; Эта функция копирует список ячеек, заменяя сами ячейки, но не меняя значения. Не идёт вглубь
(defun copy-cells (lst) 
    (let ((r nil)) (dolist (c (reverse lst) r) 
        (setq r (cons (mo "cell" :av "type" (aget c "type") :av "value" (aget c "value")) r))))
)

;; for range indexable
(aclosure ac :attribute "opsem" :type "for range indexable" :instance i :stage nil 
    :ap i "indexable" ind :do 
    ; Могут быть следующие стадии: array type, slice type, string type
    (update-push-aclosure ac :stage (otype (aget ind "type")))
    (clear-update-eval-aclosure ac :instance ind :attribute "opsem::rvalue")
)
; Сведём случай среза к массиву
(aclosure ac :attribute "opsem" :type "for range indexable" :instance i :stage "slice type" 
    :value sl :ap sl "offset" ofst :ap sl "length" len :do 
    ; Атрибуты, кроме среза, не меняются
    (clear-update-eval-aclosure ac :instance (mo "for range indexable" 
    :av "index" (aget i "index") 
    :av "value" (aget i "value")
    :av "operation" (aget i "operation") 
    :av "indexable" (mo "array value" 
        :av "type" (co "array type" :av "len" len :ap "elem type" (aget sl "type" "elem type"))
        :av "elements" (copy-cells (subseq (aget sl (aseq "array" "elements")) ofst (+ ofst len))))
    :av "body" (aget i "body")))
)
; Сведём случай строки к массиву
(aclosure ac :attribute "opsem" :type "for range indexable" :instance i :stage "string type" 
    :value pr :ap pr "value" s :do 
    (clear-update-eval-aclosure ac :instance (mo "for range indexable" 
    :av "index" (aget i "index") 
    :av "value" (aget i "value") 
    :av "operation" (aget i "operation") 
    :av "indexable" (mo "array value" 
        :av "type" (co "array type" :av "len" (length s) 
            :av "elem type" (co "unsigned int type" :av "bit size" 8)) 
        :av "value" (map 'list #'char-code s))))
)
; Наконец, рассмотрим случай для массива
(aclosure ac :attribute "opsem" :type "for range indexable" :instance i :stage "array type" 
    :value arr :do 
    (clear-update-eval-aclosure ac :stage "evaluating" :av "now" 0 :av "left" (copy-cells (aget arr "value")))
)
; Выполняет итерацию цикла: присваивает значения на текущем шаге, и запускает тело цикла
(aclosure ac :attribute "opsem" :type "for range indexable" :instance i :stage "evaluating" 
    :ap ac "left" left :av ac "now" k :agent a :do 
    (aset a "variable cell" (aget i "index") k)
    (aset a "variable cell" (aget i "value") (car left))
    (update-push-aclosure ac :av "now" (1+ k) :av "left" (cdr left))
    (clear-update-eval-aclosure ac :instance (aget i "body"))
)

;; for range map
; Вычисляем выражение, которое должно в итоге дать карту
(aclosure ac :attribute "opsem" :type "for range map" :instance i :stage nil :do 
    (update-push-aclosure ac :stage "map type")
    (clear-update-eval-aclosure ac :instance (aget i "map") :attribute "opsem::rvalue")
)
; Сохраняем затеняемые значения переменных, переходим к итерациям цикла
(aclosure ac :attribute "opsem" :type "for range map" :instance i :stage "map type" 
    :value m :ap m "entry" mv :p (attributes mv) ks :p nil vs :do 
    (dolist (k (reverse ks)) (setq vs (cons (aget mv k) vs)))  ; cоздаем список значений
    ; Переходим к итерациям цикла
    (clear-update-eval-aclosure ac :stage "evaluating" :av "keys" ks :av "values" (copy-cells vs))
)
; Выполняет итерацию цикла: присваивает значения на текущем шаге, и запускает тело цикла
(aclosure ac :attribute "opsem" :type "for range map" :instance i :stage "evaluating" 
    :ap ac "keys" ks :ap ac "values" vs :agent a :do 
    (aset a "variable cell" (aget i "key") (car ks))
    (aset a "variable cell" (aget i "values") (car vs))
    (update-push-aclosure ac :av "keys" (cdr ks) :av "values" (cdr vs))
    (clear-update-eval-aclosure ac :instance (aget i "body"))
)

;; for range int
; Вычисляет количество итераций
(aclosure ac :attribute "opsem" :type "for range int" :instance i :stage nil :do 
    (update-push-aclosure ac :stage "int type")
    (clear-update-eval-aclosure ac :instance (aget i "max") :attribute "opsem::rvalue")
)
; Сохраняет переменные, если нужно. Запускает итерации цикла
(aclosure ac :attribute "opsem" :type "for range int" :instance i :stage "int type" 
    :value m :do 
    (clear-update-eval-aclosure ac :stage "evaluating" :av "max" m :av "now" 0)
)
; Выполняет итерацию цикла: присваивает новое значение, запускает тело цикла
(aclosure ac :attribute "opsem" :type "for range int" :instance i :stage "evaluating" 
    :ap ac "max" m :av ac "now" k :agent a :v (< k m) T :do 
    (aset a "variable cell" (aget i "value") k)
    (update-push-aclosure ac :av "max" m :av "now" (1+ k))
    (clear-update-eval-aclosure ac :instance (aget i "body"))
)


;; return statement
; Проверяет, есть ли возвращаемые значения, и вычисляет первое из них
(aclosure ac :attribute "opsem" :type "return stmt" :instance i :stage nil 
    :ap ac 1 left :do 
    (update-push-aclosure ac :stage "exiting before function")
    (match :v (null left) T :exit 
        (update-push-aclosure ac :stage "evaluating" :av "left" (cdr left))
        (clear-update-eval-aclosure ac :instance (car left) :attribute "opsem::rvalue"))
)
; Вычисляет очередное возвращаемое значение
(aclosure ac :attribute "opsem" :type "return stmt" :instance i :stage "evaluating" 
    :value v :ap ac "left" left :ap ac "done" d :do 
    (match :v (null left) T :do (reverse d) 
    :exit (update-push-aclosure ac :av "left" (cdr left) :av "done" (cons v d))
          (clear-update-eval-aclosure ac :instance (car left) :attribute "opsem::rvalue"))
)
; Выходит из всех конструкций языка, пока не встретит функцию. Результат возвращает
(aclosure ac :attribute "opsem" :type "return stmt" :instance i :stage "exiting before function" 
    :value d :p (pop-aclosure ac) ac1 :p (aget ac1 "instance") i1 :do 
    ; если встретили блок, то нужно вернуть значения всем затененнным переменным
    (nmatch :v (is-instance i1 "block") T 
    :exit (push-aclosure ac) (update-eval-aclosure ac1 :stage "variable back"))
    ; если встретили функцию, то возвращаем значение
    ; т.к. функция находилась на стадии вычисления тела функции
    :v (is-instance i1 "function call") T 
    :exit d (push-aclosure ac1)
    ; иначе повторяем то же самое, но уже со следующим замыканием
    :do d (eval-aclosure ac)
)

;; break statement
(aclosure ac :attribute "opsem" :type "break stmt" :instance i :stage nil 
    :ap i 1 ln :p (pop-aclosure ac) ac1 :ap ac1 "instance" i1 :ap ac1 "label" ln1 :do
    ; если встречен блок, то возвращает значения всем затененным переменным
    (nmatch :v (is-instance i1 "block") T 
    :exit (push-aclosure ac) (update-eval-aclosure ac1 :stage "variable back")
    ; если нашлась конструкция (for, switch, select), которую нужно завершить, то завершается обработка break
    :v (and (is-instance i1 "for stmt") (or (not ln) (string= ln ln1))) :exit nil 
    :v (and (is-instance i1 "switch stmt") (or (not ln) (string= ln ln1))) :exit nil 
    ; иначе продолжается выход из конструкций языка по стеку
    :do (eval-aclosure ac))
)

;; continue statement
(aclosure ac :attribute "opsem" :type "continue stmt" :instance i :stage nil 
    :ap i 1 ln :p (pop-aclosure ac) ac1 :ap ac1 "instance" i1 :ap ac1 "label" ln1 :do 
    ; если встречен блок или цикл, то возвращает значения всем затененным переменным
    (nmatch :v (is-instance i1 "block") T 
    :exit (push-aclosure ac) (update-eval-aclosure ac1 :stage "variable back")
    ; если нашлась конструкция, которую нужно перевести на следующий шаг, то завершается обработка continue
    :v (and (is-instance i1 "for stmt") (or (not ln) (string= ln ln1))) :exit nil 
    ; иначе продолжается выход из конструкций языка по стеку
    :do (eval-aclosure ac))
)

;; goto statement
(aclosure ac :attribute "opsem" :type "goto stmt" :instance i :stage nil 
    :ap i 1 ln :p (pop-aclosure ac) ac1 :ap ac1 "instance" i1 :do 
    ; если попалось помеченное нужной меткой выражение, то запускаем его с начала
    (match :ap i1 "label" ln1 :v ln1 T :v (string= ln ln1) T 
    :do (update-eval-aclosure ac1 :stage nil)
    ; если попался блок, то проверяем список всех меток, находящихся в нем
    :exit (match :v (is-instance i1 "block") T :ap i1 "label positions" lp :ap lp ln pos :do 
    ; если нужная метка найдена, то будет искать в этой инструкции (м.б. это ещё один блок)
    ; так же меняем исполнение инструкций этого блока на ту, в которой нашлась метка
    (match :v pos T :ap ac1 "statements" sts :p (nthcdr pos sts) scdr :do 
    (update-push-aclosure ac1 :av "left" (cdr scdr)) 
    (update-push-aclosure ac1 :instance (car scdr)) 
    (eval-aclosure ac)
    ; если нужной метки в этом блоке не оказалось, то возвращаем прежние значения затененных переменных
    :exit (push-aclosure ac) (update-push-aclosure ac1 :stage "variable back"))
    ; если попался не блок, то пропускаем
    :exit nil))
)