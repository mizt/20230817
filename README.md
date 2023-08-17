##### build

```
cd "$(dirname "$0")"
cd ./
clang++ -std=c++20 -Wc++20-extensions -fobjc-arc -O3 -framework Cocoa ./main.mm -o ./main
```