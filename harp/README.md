#harp-babel

Harp boilerplate with babeljs and webpack for ES6+ friendly development.

*important*
Gulp has been removed from this project, webpack is significantly faster at compiling Babel.
See this branch for how to use it with [gulp](https://github.com/glued/harp-babel/tree/babel-gulp-v6)

##setup

	harp init -b glued/harp-babel
	npm install

###Run
Run for development
`npm run dev`

Run for production
`npm run prod`

In production, the javascript is minified and sourcemaps are removed.
This will also lint your code using ESLint and JSCSrc


These commands are defined in package.json

##Libs

####Harp
Static Site Server/Generator with built-in preprocessing ( Jade, less, etc )

[http://harpjs.com/](http://harpjs.com/)
[https://github.com/sintaxi/harp](https://github.com/sintaxi/harp)

####Babel
Babel is a compiler for writing next generation JavaScript

[https://babeljs.io/](https://babeljs.io/)
[https://github.com/babel/babel](https://github.com/babel/babel)

####Webpack
[https://github.com/webpack/webpack](https://github.com/webpack/webpack)

####Eslint
ESLint is a tool for identifying and reporting on patterns found in ECMAScript/JavaScript code.
[https://github.com/eslint/eslint](https://github.com/eslint/eslint)
[https://github.com/babel/babel-eslint](https://github.com/babel/babel-eslint)

###JSCSrc
JSCS is a code style linter for programmatically enforcing your style guide.
[https://github.com/jscs-dev/node-jscs](https://github.com/jscs-dev/node-jscs)
[https://github.com/jscs-dev/babel-jscs](https://github.com/jscs-dev/babel-jscs)
