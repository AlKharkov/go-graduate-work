package main

import (
	"fmt"
	"time"
)

// Константы
const (
	Pi       = 3.14159
	MaxCount = 100
	AppName  = "ASTDemo"
)

// Типы
type UserID int
type User struct {
	ID        int
	Name      string
	Email     string
	CreatedAt time.Time
}
type UserMap map[UserID]User
type UserSlice []User
type HandlerFunc func(string) error

// Глобальные переменные
var (
	defaultUser = User{ID: 1, Name: "Default", Email: "default@example.com", CreatedAt: time.Now()}
	userCache   = make(UserMap)
	debugMode   = true
)

// Функция с параметрами и возвращаемыми значениями
func calculateSum(a, b int) int {
	return a + b
}

// Функция с несколькими возвращаемыми значениями
func divideAndRemainder(x, y int) (int, int, error) {
	if y == 0 {
		return 0, 0, fmt.Errorf("division by zero")
	}
	return x / y, x % y, nil
}

// Метод с ресивером
func (u User) GetFullName() string {
	return u.Name
}

// Метод с указателем
func (u *User) UpdateEmail(newEmail string) {
	u.Email = newEmail
}

// Основная функция с различными конструкциями
func main() {
	// Объявления переменных
	var count int
	var message string = "Hello"
	name := "Go"
	x, y := 10, 20

	// Присваивания
	count = 5
	x, y = y, x
	count += 10
	x *= 2

	// Условные операторы
	if count > 0 {
		fmt.Println("Count is positive")
	} else if count == 0 {
		fmt.Println("Count is zero")
	} else {
		fmt.Println("Count is negative")
	}

	// If с инициализацией
	if err := validateInput(name); err != nil {
		fmt.Println("Error:", err)
		return
	}

	// Циклы
	// For классический
	for i := 0; i < 10; i++ {
		fmt.Println("i =", i)
	}

	// For как while
	sum := 0
	for sum < 100 {
		sum += 10
	}

	// Бесконечный цикл
	done := false
	for {
		if done {
			break
		}
		done = true
	}

	// Range по массиву/срезу
	numbers := []int{1, 2, 3, 4, 5}
	for index, value := range numbers {
		fmt.Printf("numbers[%d] = %d\n", index, value)
	}

	// Range по мапе
	userMap := map[string]int{"a": 1, "b": 2, "c": 3}
	for key, value := range userMap {
		fmt.Println(key, value)
	}

	// Range по каналу
	ch := make(chan int)
	go func() {
		for i := 0; i < 5; i++ {
			ch <- i
		}
		close(ch)
	}()
	for val := range ch {
		fmt.Println("Channel value:", val)
	}

	// Switch
	switch count {
	case 0:
		fmt.Println("Zero")
	case 1, 2:
		fmt.Println("One or Two")
	default:
		fmt.Println("Other")
	}

	// Switch с условием
	switch {
	case count < 0:
		fmt.Println("Negative")
	case count > 0:
		fmt.Println("Positive")
	default:
		fmt.Println("Zero")
	}

	// Type switch
	var data interface{} = "Hello"
	switch v := data.(type) {
	case int:
		fmt.Printf("Integer: %d\n", v)
	case string:
		fmt.Printf("String: %s\n", v)
	case bool:
		fmt.Printf("Boolean: %t\n", v)
	default:
		fmt.Printf("Unknown type: %T\n", v)
	}

	// Select
	ch1 := make(chan int)
	ch2 := make(chan string)
	go func() { ch1 <- 42 }()
	go func() { ch2 <- "Hello" }()

	select {
	case val := <-ch1:
		fmt.Println("From ch1:", val)
	case msg := <-ch2:
		fmt.Println("From ch2:", msg)
	default:
		fmt.Println("No channels ready")
	}

	// Отложенный вызов
	defer fmt.Println("Deferred function call")
	defer func() {
		if r := recover(); r != nil {
			fmt.Println("Recovered:", r)
		}
	}()

	// Go-рутина
	go func() {
		fmt.Println("Goroutine started")
	}()

	// Вызов функции
	result := calculateSum(x, y)
	quot, rem, err := divideAndRemainder(10, 3)
	if err != nil {
		fmt.Println(err)
	}
	fmt.Println("Result:", result, "Quot:", quot, "Rem:", rem)

	// Вызов метода
	user := User{ID: 1, Name: "Alice", Email: "alice@example.com", CreatedAt: time.Now()}
	user.UpdateEmail("alice@new.com")
	fullName := user.GetFullName()
	fmt.Println("User:", fullName)

	// Работа с массивами
	var arr [5]int = [5]int{1, 2, 3, 4, 5}
	arr2 := [...]int{10, 20, 30}
	fmt.Println(arr, arr2)

	// Работа со срезами
	slice := make([]int, 0, 10)
	slice = append(slice, 1, 2, 3)
	subSlice := slice[1:3]
	fmt.Println("Slice:", slice, "SubSlice:", subSlice)

	// Работа с мапами
	m := make(map[string]int)
	m["one"] = 1
	m["two"] = 2
	delete(m, "two")
	val, ok := m["one"]
	if ok {
		fmt.Println("Value:", val)
	}

	// Каналы
	ch3 := make(chan string, 2)
	ch3 <- "buffered"
	ch3 <- "channel"
	close(ch3)
	for msg := range ch3 {
		fmt.Println("Buffered channel:", msg)
	}

	// Указатели
	var ptr *int
	ptr = &count
	*ptr = 100
	fmt.Println("Count:", count, "Ptr:", *ptr)

	// Работа с интерфейсами
	var iface interface{} = "interface value"
	fmt.Println(iface)

	// Type assertion
	str, ok := iface.(string)
	if ok {
		fmt.Println("String:", str)
	}

	// Структуры и поля
	type Point struct {
		X, Y int
	}
	p := Point{X: 10, Y: 20}
	fmt.Println("Point:", p.X, p.Y)

	// Вложенные структуры
	type Circle struct {
		Point
		Radius int
	}
	c := Circle{Point: Point{X: 0, Y: 0}, Radius: 5}
	fmt.Println("Circle:", c.X, c.Y, c.Radius)

	// Функциональные литералы (замыкания)
	adder := func(a, b int) int {
		return a + b
	}
	fmt.Println("Adder result:", adder(5, 10))

	// Обработка паники
	func() {
		defer func() {
			if r := recover(); r != nil {
				fmt.Println("Recovered from panic:", r)
			}
		}()
		panic("something went wrong")
	}()

	// Перебор с использованием goto
	i := 0
loop:
	if i < 5 {
		fmt.Println("i in loop:", i)
		i++
		goto loop
	}

	// Labeled break/continue
outer:
	for i := 0; i < 3; i++ {
		for j := 0; j < 3; j++ {
			if i == 1 && j == 1 {
				break outer
			}
			fmt.Println(i, j)
		}
	}

	// Empty statement

	// Инкремент/декремент
	counter := 0
	counter++
	counter--

	// Send to channel
	ch4 := make(chan int, 1)
	go func() {
		ch4 <- 100
	}()

	// Receive from channel
	valRecv := <-ch4
	fmt.Println("Received:", valRecv)

	// Type conversion
	var integer int = 42
	var float float64 = float64(integer)
	fmt.Println("Converted:", float)

	// Unary expressions
	negative := -42
	positive := +42
	notBool := !true
	addressOf := &count
	deref := *addressOf
	bitwiseNot := ^1

	// Binary expressions
	sumExpr := 1 + 2
	subExpr := 1 - 2
	mulExpr := 1 * 2
	divExpr := 1 / 2
	modExpr := 1 % 2
	shiftLeft := 1 << 2
	shiftRight := 1 >> 2
	bitwiseAnd := 1 & 2
	bitwiseOr := 1 | 2
	bitwiseXor := 1 ^ 2
	bitwiseAndNot := 1 &^ 2
	equal := 1 == 2
	notEqual := 1 != 2
	less := 1 < 2
	lessEqual := 1 <= 2
	greater := 1 > 2
	greaterEqual := 1 >= 2
	logicalAnd := true && false
	logicalOr := true || false

	// Используем все переменные чтобы избежать warnings
	fmt.Println(negative, positive, notBool, addressOf, deref, bitwiseNot)
	fmt.Println(sumExpr, subExpr, mulExpr, divExpr, modExpr, shiftLeft, shiftRight)
	fmt.Println(bitwiseAnd, bitwiseOr, bitwiseXor, bitwiseAndNot)
	fmt.Println(equal, notEqual, less, lessEqual, greater, greaterEqual)
	fmt.Println(logicalAnd, logicalOr, valRecv, counter)

	// Вывод всех созданных объектов чтобы избежать предупреждений
	fmt.Println(message, name, done, sum, defaultUser, userCache, debugMode, numbers)
	fmt.Println(userMap, data, ch1, ch2, m, ptr, iface, str, p, c, arr, arr2)
	fmt.Println(slice, subSlice, ch3, ch4, adder, i, result, quot, rem, err)
	fmt.Println(fullName, quot, rem, err)
}

// Вспомогательная функция для if с инициализацией
func validateInput(name string) error {
	if name == "" {
		return fmt.Errorf("name is empty")
	}
	return nil
}

// Функция с переменным числом аргументов
func sumAll(values ...int) int {
	total := 0
	for _, v := range values {
		total += v
	}
	return total
}
