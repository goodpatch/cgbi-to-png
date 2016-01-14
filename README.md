# CgbiToPng

**Description**

This library will convert the CgBIPNG to normal PNG.

[CgBI Format](http://iphonedevwiki.net/index.php/CgBI_file_format)

## How to Use

```elixir
alias CgbiToPng

png = CgbiToPng.to_png("File Path") # Return PNG Binary
File.write("Output Path", png)
```

## Installation

FIX
