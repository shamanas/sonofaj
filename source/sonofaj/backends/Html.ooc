import io/[File, FileWriter, Writer]
import text/StringTokenizer
import structs/[ArrayList,HashMap]

import sonofaj/[Doc, Nodes, Repository, Visitor]
import sonofaj/backends/Backend

// TODO: Fix bug (see lang/Iterators -> Iterator::eachUntil and structs/ArrayList -> ArrayList::sort and literals in structs/List)
// Seems to be a bug of a single argument function with the argument being a function that returns bool
// TODO: Generate anchors on every class / function / cover / enum declaration and append them to links
// TODO: Create literals section? 

argSplit : func (argStr : String) -> ArrayList<String> {
    // Splits an argument string correctly, that is, taking in mind that Func's can contain strings
    args := argStr split(',')
    for(i in 0..args getSize()) {
        args[i] = args[i] trimLeft()
        if(args[i] contains?("Func") && args[i] find("(",0) != -1 && args[i] find(")",0) == -1) {
            for(j in i+1..args getSize()) {
                args[i] = args[i] + ',' + args[j]
                args removeAt(j)
                if(args[i] find(")",0) != -1) {
                    break
                }
            }
        } else if(args[i] contains?("<") && !args[i] contains?(">")) {
            for(j in i+1..args getSize()) {
                args[i] = args[i] + ',' + args[j]
                args removeAt(j)
                if(args[i] contains?(">")) {
                    break
                }
            }
        }
    }
    args
}

getRightParen : func (source : String, left : Int) -> Int {
    open := 1
    closed := 0
    for(i in left+1..source length()) {
        if(source[i] == '(') {
            open += 1
        } else if(source[i] == ')') {
            closed += 1
        }
        
        if(open == closed) {
            return i
        }
    }
    -1
}

HtmlVisitor : class extends Visitor {
    html : HtmlWriter
    init : func(=html)
    
    visitFunction : func(node : SFunction) {
        visitFunction(node,"func")
    }
    
    visitCover : func(node : SCover) {
        identifier := node getIdentifier()
        html openTag("p","cover")
        html writeHtmlLine(html getTag("span","coverdecl","Cover <span class=\"covername\">%s</span>" format(identifier)))
        // Indent for members
        html indent()
        // From
        if(node from_ != null && !node from_ empty?()) {
            html write(HtmlWriter Ln)
            html writeHtmlLine(html getTag("span","from","From <span class=\"ctype\">%s</span>" format(node from_)))
        }
        // Extends
        if(node extends_ != null && !node extends_ empty?()) {
            html write(HtmlWriter Ln)
            html writeHtmlLine(html getTag("span","extends","Extends %s" format(html getHtmlType(node getExtendsRef()))))
        }
        // Doc
        if(node doc != null && !node doc empty?()) {
            html write(HtmlWriter Ln)
            node doc = formatDoc(node doc)
            html writeHtmlLine(html getTag("span","doc",html formatDoc(node doc)))
        }
        // Get members
        for(member in node members) {
            html write(HtmlWriter Ln)
            match (member node type) {
                case "method" => {
                    if(member node as SFunction hasModifier("static"))
                        visitFunction(member node as SFunction, "staticmethod")
                    else
                        visitFunction(member node as SFunction, "method")
                }
                case "field" => {
                    visitGlobalVariable(member node as SGlobalVariable, "field")
                }
                case "enum" => {
                    visitEnum(member node as SEnum)
                }
            }
        }
        html dedent()
        html closeTag("p")
    }
    
    //TODO: Add private section for __load__ and __defaults__ (or maybe all members starting and ending with __ ? )
    visitClass : func(node : SClass) {
        identifier := node getIdentifier()
        html openTag("p","class")
        html writeHtmlLine(html getTag("span","classdecl","Class <span class=\"classname\">%s</span>" format(identifier)))
        // Indent for members
        html indent()
        // Extends
        if(node extends_ != null && !node extends_ empty?()) {
            html write(HtmlWriter Ln)
            html writeHtmlLine(html getTag("span","extends","Extends %s" format(html getHtmlType(node getExtendsRef()))))
        }
        // Doc
        if(node doc != null && !node doc empty?()) {
            html write(HtmlWriter Ln)
            node doc = formatDoc(node doc)
            html writeHtmlLine(html getTag("span","doc",html formatDoc(node doc)))
        }
        // Get members
        for(member in node members) {
            html write(HtmlWriter Ln)
            match (member node type) {
                case "method" => {
                    if(member node name startsWith?("__") && member node name endsWith?("__"))
                        visitFunction(member node as SFunction, "privatemethod")
                    else if(member node as SFunction hasModifier("static"))
                        visitFunction(member node as SFunction, "staticmethod")
                    else
                        visitFunction(member node as SFunction, "method")
                }
                case "field" => {
                    visitGlobalVariable(member node as SGlobalVariable, "field")
                }
                case "enum" => {
                    visitEnum(member node as SEnum)
                }
            }
        }
        html dedent()
        html closeTag("p")
    }
    
    visitFunction : func ~directive(node : SFunction, directive : String) {
        signature := node getSignature(true)
        body : String = ""
        // Get name
        nameNsuffix : String
        if(signature find("(",0) != -1) {
            if(signature find("->",0) != -1) {
                if(signature findAll("->")[signature findAll("->") getSize() - 1] < signature find("(",0)) {
                    nameNsuffix = signature substring(0,signature findAll("->")[0])
                } else {
                    nameNsuffix = signature substring(0,signature find("(",0))
                }
            } else {
                nameNsuffix = signature substring(0,signature find("(",0))
            }
        } else if(signature find("->",0) != -1) {
            nameNsuffix = signature substring(0,signature findAll("->")[0])
        } else {
            // No arguments, no return type
            nameNsuffix = signature
        }
        name := nameNsuffix substring(0,nameNsuffix find("~",0))
        body += html getTag("span","fname",name)
        // Get suffix
        if(name != nameNsuffix) {
            suffix := nameNsuffix substring(nameNsuffix find("~",0))
            body += html getTag("span","fsuffix"," " + suffix)
        }
        // Get argument types
        leftParen := -1 as Int
        if(signature contains?("(") && !signature contains?("->")) {
            leftParen = signature findAll("(")[0]
        } else if(signature contains?("(") && signature contains?("->")) {
            if(signature findAll("(")[0] < signature findAll("->")[0]) {
                leftParen = signature findAll("(")[0]
            }
        }
        rightParen : Int = (leftParen == -1) ? -1 : getRightParen(signature,leftParen)
        if(leftParen != -1 && rightParen != -1) {
            argStr := signature substring(leftParen + 1, rightParen)
            if(argStr != null && !argStr empty?() && argStr != signature) {
                body += "( "
                args := argSplit(argStr)
                for(i in 0 .. args getSize()) {
                    arg := args[i]
                    arg = arg trimLeft()
                    if(!arg startsWith?(":")) {
                        // It has a name :)
                        body += html getTag("span","argname",arg substring(0,arg find(":",0)+2))
                        arg = arg substring(arg find(":",0)+1)
                        arg = arg trimLeft()
                    }
                    // Get argument type :) 
                    body += html getHtmlType(arg)
                    if(i != args getSize() - 1) {
                        body += ", "
                    }
                }
                body += " )"
            }
        }
        // Get return type
        if(signature find("->",0) != -1) {
            arrow := signature findAll("->")[0]
            i := 0 as Int
            while(arrow < rightParen && i+1 < signature findAll("->") getSize()) {
                i += 1
                arrow = signature findAll("->")[i]
            }
            returnType := signature substring(arrow+2)
            returnType = returnType trimLeft()
            retBody := " -> "
            retBody += html getHtmlType(returnType)
            body += html getTag("span","freturn",retBody)
        }
        // Get doc string
        if(node doc != null && !node doc empty?()) {
            body += HtmlWriter Ln
            node doc = formatDoc(node doc)
            body += html getTag("span","doc",html formatDoc(node doc))
        }
        // Close function block :) 
        body += HtmlWriter Ln
        html writeHtmlLine(html getTag("span",directive,body))
    }
    
    visitEnum : func(node : SEnum) {
        identifier := node getIdentifier()
        html openTag("p","cover")
        html writeHtmlLine(html getTag("span","enumdecl","Enum <span class=\"enumname\">%s</span>" format(identifier)))
        // Indent for members
        html indent()
        // Doc
        if(node doc != null && !node doc empty?()) {
            html write(HtmlWriter Ln)
            node doc = formatDoc(node doc)
            html writeHtmlLine(html getTag("span","doc",html formatDoc(node doc)))
        }
        // Get members
        for(member in node members) {
            html writeHtmlLine(html getTag("span","enumelement",member name))
            if(member doc != null && !member doc empty?()) {
                html indent()
                html writeHtmlLine(html getTag("span","doc",member doc))
                html dedent()
            }
        }
        html dedent()
        html closeTag("p")
    }
    
    visitGlobalVariable : func(node : SGlobalVariable) {
        visitGlobalVariable(node,"var")
    }
    
    visitGlobalVariable : func ~directive(node : SGlobalVariable, directive : String) {
        html writeHtmlLine(html getTag("span",directive,"%s -> %s" format(node name, html getHtmlType(node getTypeRef()))))
    }
}

HtmlWriter : class {
    writer : Writer
    module : SModule
    indentLevel : UInt = 0
    
    init : func(=module,=writer)
    
    getHtmlType : func(ref : String) -> String {
        pointer := 0 as Int
        reference := 0 as Int
        ref = ref trimRight()
        ref = ref trimLeft()
        while(ref endsWith?("*")) {
            pointer += 1
            ref = ref substring(0,ref length()-1)
        }
        while(ref endsWith?("@")) {
            reference += 1
            ref = ref substring(0,ref length()-1)
        }
        ref = ref trimRight()
        ref = ref trimLeft()
        
        if(ref startsWith?(":") && ref findAll(":") getSize() > 1) {
            directive := ref substring(ref findAll(":")[0]+1,ref findAll(":")[1])
            ref = ref substring(ref findAll(":")[1]+1)
            ref = ref trimRight()
            ref = ref trimLeft()
            if(ref startsWith?("`~")) {
            ref = ref substring(2)
            }
            if(ref endsWith?("`")) {
                ref = ref substring(0,ref length()-1)
            }
            
            ret := "<a class=\"%s\" href=\"" format(directive)
        
            modulePath := ref substring(0,ref find(" ",0)) // Get the module path
            root := modulePath substring(0,modulePath find("/",0)) // Get the root folder of the module
            thisRoot := module path substring(0,module path find("/",0)) // Get the root of the current module
            if(root != thisRoot) {
                ret += "../" times(module path findAll("/") getSize() + 1) + "html/" + modulePath
            } else {
                ret += "../" times(module path findAll("/") getSize()) + root + "/" + modulePath substring(modulePath find("/",0)+1)
            }
            
            typeStr := ref substring(ref find(" ",0) + 1)
            if(typeStr contains?("<") && typeStr contains?(">")) {
                // Evaluate generic parameters
                types := argSplit(typeStr substring(typeStr findAll("<")[0] + 1,typeStr findAll(">")[typeStr findAll(">") getSize() - 1]))
                end := typeStr substring(typeStr findAll(">")[typeStr findAll(">") getSize() - 1])
                typeStr = typeStr substring(0,typeStr findAll("<")[0] + 1)
                for(i in 0..types getSize()) {
                    typeStr += getHtmlType(types[i])
                    if(i != types getSize() - 1) {
                        typeStr += ','
                    }
                }
                typeStr += end
                // Html escaping =D
                typeStr = typeStr replaceAll("<","&lt;")
                typeStr = typeStr replaceAll(">","&gt;")
            }
                        
            typeStr += "*" times(pointer)
            typeStr += "@" times(reference)
            
            ret += ".html\">%s</a>" format(typeStr)
            return ret
        } else if(ref startsWith?("Func")) {
            // Func types
            ret := "<span class=\"func\">Func"
            if(ref find("(",0) != -1 && ref find(")",0) != -1) {
                ret += "( "
                argStr := ref substring(ref find("(",0)+1,ref findAll(")")[ref findAll(")") getSize() - 1])
                args := argSplit(argStr)
                for(i in 0..args getSize()) {
                    // Get argument type
                    ret += getHtmlType(args[i])
                    if(i != args getSize() - 1) {
                        ret += ','
                    }
                }
                ret += " )"
            }
            if(ref find("->",0) != -1) {
                lastIndx := ref findAll("->")[ref findAll("->") getSize() - 1]
                retType? := false
                if(ref find(")",0) != -1) {
                    if(lastIndx > ref findAll(")")[ref findAll(")") getSize() - 1]) { // This is too make sure that if we have a Func argument we dont take its arrow and not the one of the top-most Func
                        //TODO: Make sure we dont take the arrow of a Func that is a return type of the top-most Func
                        retType? = true
                    }
                } else {
                    retType? = true
                }
                
                if(retType?) {
                    retType := ref substring(lastIndx + 2)
                    // Get return type
                    ret += " -> " + getHtmlType(retType)
                }
            }
            ret += "</span>"
            return ret
        } else if(ref startsWith?("(") && ref endsWith?(")")) {
            // Tuple
            ret := "("
            ref = ref substring(1,ref length() - 1)
            types := argSplit(ref)
            for(type in types) {
                ret += getHtmlType(type)
                if(types indexOf(type) != types getSize() - 1) {
                    ret += ','
                }
            }
            ret += ")"
            return ret
        }
        
        ref += "*" times(pointer)
        ref += "@" times(reference)
        ref
    }
    
    writeModuleLine : func(path : String) {
        writeLine("<h1 class=\"module\">" + path + "</h1>")
    }
    
    writeLine : func(str : String) {
        write(str+"\n")
    }
    
    writeHtmlLine : func(str : String) {
        writeHtml(str+"\n")
    }
    
    openTag : func(tag, class_ : String) {
        writeHtmlLine("<%s class=\"%s\">" format(tag,class_))
    }
    
    closeTag : func(tag : String) {
        writeHtmlLine("</%s>" format(tag))
    }
    
    writeBeginning : func(title : String) {
        style := "../" times(module path findAll("/") getSize() + 1) +  "html/style.css"
        this writeLine("<html>"). indent(). writeLine("<head><title>%s</title><link rel=\"StyleSheet\" href=\"%s\" TYPE=\"text/css\" media=\"screen\" /></head>" format(module name, style)). writeLine("<body>"). indent(). writeLine("<div id=\"body\">"). indent()
    }
    
    writeEnd : func {
        this dedent(). writeLine("</div>"). dedent(). writeLine(""). writeLine("</body>"). dedent(). writeLine("</html>")
    }
    
    writeHtml : func(str : String) {
        writeNoIndent(htmlIndentOpen() + str + htmlIndentClose())
    }
    
    htmlIndentOpen : func -> String {
        return "<pre>" + "    " times(indentLevel-2)
    }
    
    htmlIndentClose : func -> String {
        return "</pre>"
    }
    
    getTag : func(tagName, class_, contents : String) -> String {
        return "<%s class=\"%s\">" format(tagName,class_) + contents + "</%s>" format(tagName)
    }
    
    Ln := static "\n\n"
    
    writeNoIndent : func(str : String) {
        writer write(str)
    }
    
    indent : func {
        indentLevel += 1
    }
    
    dedent : func {
        indentLevel -= 1
    }
    
    write : func(str : String) {
        writer write("    " times(indentLevel) + str)
    }
    
    formatDoc : func(doc : String) -> String {
        lines := doc split('\n')
        for(i in 0 .. lines getSize()) {
            lines[i] = lines[i] trimLeft()
            lines[i] = "    " times(indentLevel - 2) + lines[i]
        }
        lines join('\n')
    }
    
    close : func {
        writer close()
    }
}

HtmlBackend : class extends Backend {
    outPath : File

    init : func (=repo) {
        outPath = repo root getChild("html")
        outPath mkdirs()
    }
    
    handle : func(module : SModule) {
        if(module path != null && !module path empty?()) {
            ("Handling module " + module name + ".") println() 
            file := outPath getChild(module path + ".html") /* TODO: does this work in all cases? */
            file parent mkdirs()
            html := HtmlWriter new(module,FileWriter new(file))
            visitor := HtmlVisitor new(html)
            html writeBeginning(module name) \
               .writeModuleLine(module path) \
               .writeLine("")
            visitor visitChildren(module)
            html writeEnd()
            html close()
            ("Module " + module name + " handled.") println()
        }
    }
    
    run : func {
        for(module in repo getModules()) {
            handle(module)
        }
    }
}

