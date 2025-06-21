# Identify frontend

## Candid field name lookup table

Candid uses hashed field names.
To show the user likely names of the original candid, a lookup table is generated. 

The resulting names are not guaranteed to be unique, so they might not match the original candid field names!

```
find .. -name "*.did" -exec cat {} \; | grep -E '^\s*[a-zA-Z_][a-zA-Z0-9_]*\s*:' | sed -E 's/^\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*:.*$/\1/' | sort | uniq > ./src/frontend/identify/candidFieldNames.txt
```

