package main

// Константы
const Pi = 3.14
const Greeting = "hello"

const (
	A = iota
	B
	C
)

const (
	KB = 1 << (10 * (iota + 1))
	MB
	GB
)

// Типы
type MyInt int
type Point struct {
	X int
	Y int
}
type IntSlice []int
type IntArray [5]int
type IntMap map[string]int
type Handler func(int) int
type Reader interface {
	Read() int
}

// Глобальные переменные
var (
	counter int
	name    string = "go"
	values         = []int{1, 2, 3}
)

// Функция с параметрами и результатами
func add(a, b int) int {
	return a + b
}

// Функция с именованными результатами
func divmod(a, b int) (q, r int) {
	q = a / b
	r = a % b
	return
}

// Функция с variadic-параметром
func sum(nums ...int) int {
	total := 0
	for _, n := range nums {
		total += n
	}
	return total
}

// Функция, возвращающая функцию (замыкание)
func makeAdder(x int) func(int) int {
	return func(y int) int {
		return x + y
	}
}

// Методы
func (p Point) Distance() int {
	return p.X*p.X + p.Y*p.Y
}

func (p *Point) Move(dx, dy int) {
	p.X += dx
	p.Y += dy
}

func (m MyInt) Double() MyInt {
	return m * 2
}

// Метод, реализующий интерфейс
func (p Point) Read() int {
	return p.X
}

// Функция, принимающая интерфейс
func readValue(r Reader) int {
	return r.Read()
}

// Основная функция
func main() {
	// Объявление переменных
	var x int = 10
	var y = 20
	z := 30
	_ = z

	// Арифметика
	sum1 := x + y
	diff := x - y
	prod := x * y
	quot := x / y
	rem := x % y

	// Побитовые операции
	bitAnd := x & y
	bitOr := x | y
	bitXor := x ^ y
	bitAndNot := x &^ y
	shiftL := x << 2
	shiftR := x >> 2

	// Логические операции
	b1 := true
	b2 := false
	and := b1 && b2
	or := b1 || b2
	not := !b1

	// Сравнения
	eq := x == y
	neq := x != y
	lt := x < y
	le := x <= y
	gt := x > y
	ge := x >= y

	// Унарные операции
	neg := -x
	pos := +x
	bitNot := ^x
	ptr := &x
	deref := *ptr

	// Использование всех результатов
	_, _, _, _, _ = sum1, diff, prod, quot, rem
	_, _, _, _, _, _ = bitAnd, bitOr, bitXor, bitAndNot, shiftL, shiftR
	_, _, _ = and, or, not
	_, _, _, _, _, _ = eq, neq, lt, le, gt, ge
	_, _, _, _ = neg, pos, bitNot, deref

	// Условия
	if x > 5 {
		x = 100
	} else if x > 0 {
		x = 50
	} else {
		x = 0
	}

	// If с init
	if v := x * 2; v > 100 {
		_ = v
	}

	// Циклы
	for i := 0; i < 10; i++ {
		_ = i
	}

	// While-подобный
	n := 0
	for n < 5 {
		n++
	}

	// Бесконечный цикл с break
	for {
		n++
		if n > 10 {
			break
		}
	}

	// For range по срезу
	slice := []int{1, 2, 3, 4, 5}
	for i, v := range slice {
		_, _ = i, v
	}

	// For range по массиву
	arr := [3]int{10, 20, 30}
	for i, v := range arr {
		_, _ = i, v
	}

	// For range по строке
	str := "hello"
	for i, r := range str {
		_, _ = i, r
	}

	// For range по карте
	m := map[string]int{"a": 1, "b": 2}
	for k, v := range m {
		_, _ = k, v
	}

	// For range по каналу
	ch := make(chan int, 3)
	ch <- 1
	ch <- 2
	close(ch)
	for v := range ch {
		_ = v
	}

	// For range по int (Go 1.22+)
	for i := range 5 {
		_ = i
	}

	// Switch
	switch x {
	case 0:
		x = 1
	case 1, 2, 3:
		x = 2
	default:
		x = 3
	}

	// Switch с init
	switch v := x; v {
	case 100:
		_ = v
	}

	// Type switch
	var iface any = 42
	switch v := iface.(type) {
	case int:
		_ = v
	case string:
		_ = v
	case bool:
		_ = v
	default:
		_ = v
	}

	// Select
	ch1 := make(chan int, 1)
	ch2 := make(chan int, 1)
	ch1 <- 1
	select {
	case v := <-ch1:
		_ = v
	case v := <-ch2:
		_ = v
	default:
		_ = 0
	}

	// Метки и goto
	i := 0
loop:
	if i < 3 {
		i++
		goto loop
	}

	// Break и continue с метками
outer:
	for i := 0; i < 3; i++ {
		for j := 0; j < 3; j++ {
			if j == 1 {
				continue outer
			}
			if i == 2 {
				break outer
			}
		}
	}

	// Defer
	defer func() {
		_ = 0
	}()

	// Go
	done := make(chan bool)
	go func() {
		done <- true
	}()
	<-done

	// Составные литералы
	sliceLit := []int{1, 2, 3}
	arrLit := [3]int{1, 2, 3}
	structLit := Point{X: 1, Y: 2}
	mapLit := map[string]int{"a": 1}
	structLitUnnamed := Point{1, 2}

	_, _, _, _ = sliceLit, arrLit, structLit, mapLit
	_ = structLitUnnamed

	// Индексация
	_ = sliceLit[0]
	_ = arrLit[1]
	_ = mapLit["a"]
	_ = str[0]

	// Срезы
	_ = sliceLit[1:3]
	_ = sliceLit[:2]
	_ = sliceLit[2:]
	_ = sliceLit[1:3:5]

	// Доступ к полям
	p := Point{X: 1, Y: 2}
	_ = p.X
	_ = p.Y

	// Методы
	_ = p.Distance()
	p.Move(1, 1)

	// Method expression
	distFn := Point.Distance
	_ = distFn(p)

	// Method value
	mv := p.Distance
	_ = mv()

	// Вызовы функций
	_ = add(1, 2)
	_, _ = divmod(10, 3)
	_ = sum(1, 2, 3)
	adder := makeAdder(10)
	_ = adder(5)

	// Вызов через интерфейс
	_ = readValue(p)

	// Конверсии типов
	_ = MyInt(5)
	_ = int(MyInt(5))
	_ = float64(x)

	// Type assertion
	var anyVal any = 42
	_ = anyVal.(int)
	v, ok := anyVal.(int)
	_, _ = v, ok

	// Получение из канала
	ch3 := make(chan int, 1)
	ch3 <- 5
	_ = <-ch3

	// Присваивания с операциями
	x += 5
	x -= 3
	x *= 2
	x /= 4
	x %= 3
	x <<= 1
	x >>= 1
	x &= 7
	x |= 8
	x ^= 15
	x &^= 3

	// Инкремент и декремент
	x++
	x--

	// Указатели
	pp := &Point{X: 1, Y: 2}
	pp.X = 10
	_ = pp.X
	pp.Move(1, 1)

	// Замыкания с захватом переменных
	closure := func() int {
		return x + n
	}
	_ = closure()

	// Множественное присваивание
	a, b := 1, 2
	a, b = b, a
	_, _ = a, b

	// Множественное присваивание из функции
	q, r := divmod(10, 3)
	_, _ = q, r

	// Каналы
	chSend := make(chan int, 1)
	chSend <- 42

	chRecv := make(chan int, 1)
	chRecv <- 42
	_ = <-chRecv

	// Select с send и receive
	chA := make(chan int, 1)
	chB := make(chan int, 1)
	select {
	case chA <- 1:
		_ = 0
	case v := <-chB:
		_ = v
	}

	// Пустой оператор

	// Вложенные блоки
	{
		inner := 10
		_ = inner
	}

	// Затенение
	shadow := 1
	{
		shadow := 2
		_ = shadow
	}
	_ = shadow
}
