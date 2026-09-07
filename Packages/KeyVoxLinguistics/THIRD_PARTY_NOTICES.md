# Perceptron inference attribution

The feature schema and inference behavior are adapted into Swift from the
specifically MIT-licensed `nltk/tag/perceptron.py` in NLTK 3.9.1. The Swift
adaptation omits training, downloading, pickle, NumPy, and Python dependencies.

Source: https://github.com/nltk/nltk/blob/3.9.1/nltk/tag/perceptron.py

Copyright 2013 Matthew Honnibal.
NLTK modifications Copyright 2015 The NLTK Project.

Full upstream MIT terms:

```text
Copyright 2013 Matthew Honnibal

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
```

Optional model assets are separately attributed in `Tools/Models`. No model
assets or language default are embedded in this package.
