import structs/ArrayList

ParsingError: class extends Exception {
    init: func ~withMsg (.message) {
        super(message)
    }
}

Tag: class {
    value: String
    arguments: ArrayList<Tag>
    
    init: func (=value) {
        init(value, null)    
    }

    init: func ~withArguments (=value, =arguments) {
    
    }

    hasArguments: func -> Bool {
        arguments != null
    }
    
    toString : func -> String {
        base := value
        if(this hasArguments()) {
            base += '('
            for(i in 0..arguments getSize()) {
                base += arguments[i] toString()
                if(i != arguments getSize() - 1) {
                    base += ','
                }
            }
            base += ')'
        }
        base
    }

    parse: static func (iter: Iterator<Char>, lastChar: Char*, toplevel := true) -> Tag {
        buf := Buffer new()
        tag: Tag
        /* first: skip whitespaces and commas. */
        next: Char = iter next()
        while(next whitespace?() || next == ',') {
            next = iter next()
        }
        /* then: read the tag value. */
        while(!next whitespace?() && next != '(' && next != ',' && next != ')') {
            buf append(next)
            if(!iter hasNext?())
                break
            next = iter next()
        }
        lastChar@ = next
        tag = Tag new(buf toString())
        /* then: do we have arguments? */
        if(next == '(' && iter next() != ')') {
            iter as ReverseIterator<Char> prev()
            tag arguments = ArrayList<Tag> new()
            while(true) {
                thisLastChar: Char
                tag arguments add(parse(iter, thisLastChar&, false))
                lastChar@ = thisLastChar
                /* no more arguments. */
                if(thisLastChar == ')') {
                    next = iter next()
                    iter as ReverseIterator<Char> prev()
                    if(next == ',' && toplevel) {
                        continue
                    } else {
                        break
                    }
                } else if(thisLastChar == ',') {
                    continue
                } else {
                    ParsingError new("Huh! I didn't expect '%c'!" format(thisLastChar)) throw()
                    /* NOBODY expects '%c'!" */
                    // -> I loled :o
                }
            }
        }
        return tag
    }

    parse: static func ~string (str: String) -> Tag {
        lastChar: Char
        parse(str iterator(), lastChar&)
    }
}
