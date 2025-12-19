## Limitations
Literal type = "[" "..." "]" ElementType
Type assertions
^1  - буду разбираться что это и зачем
declarations: каждое значение должно быть явно указано (в том числе без iota)
declarations: типы обязательно указывать
interfaces
templates
function decl -> type parameters
function decl -> signature -> result -> parameter decl

## The rules of good form
1. Явно указывать стадию nil, если используются другие стадии


## In order not to forget
1. Операторы имеют свой приоритет, но вычисляются значения соответсвующих выражений слева направо(пока результат не очевиден)
2. Неявные блоки в if, ...
3. Statements ничего не возвращают, в отличие от expressions
4. math.Sin -> (mo "variable" :av "name" "math.Sin")
5. Указатель на переменную 
6. const spec: (length names) == (length inits)


## Questions
1. Проверить декларации


## Улучшения
1. Отделить константы от переменных (в агента добавить новое отношение)


## Предложения к синтаксису
1. aclosure желательные атрибуты :attribute :type :instance
2. (aset ac :attribute :type :instance :stage :agent :value ...)