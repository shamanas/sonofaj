import io/[File, FileReader]
import structs/[ArrayList, HashMap, HashBag]
import text/[StringTokenizer, json]

import sonofaj/Nodes

ModuleNotFoundException: class extends Exception {
    init: func ~withMsg (msg: String) {
        super(msg)
    }
}

Repository: class {
    root: File
    cache := HashMap<String, SModule> new()

    init: func (=root)

    getModule: func (module: String) -> SModule {
        if(!cache contains?(module))
            cache[module] = loadModule(module)
        cache[module]
    }

    getModules: func -> HashMap<String, SModule> {
        cache
    }

    loadModule: func (module: String) -> SModule {
        ("Loading module " + module) println()
        reader := FileReader new(getModuleFilename(module))
        node := SModule new(this)
        node read(JSON parse(reader, HashBag))
        node
    }
    
    getModuleFilename: func (module: String) -> String {
        filename := getModuleFilenameNoCry(module)
        if(filename == null)
            ModuleNotFoundException new(This, "Module not found: %s" format(module)) throw()
        return filename
    }

    getModuleFilenameNoCry: func (module: String) -> String {
        parts := module split('/')
        lastIndex := parts lastIndex()
        parts[lastIndex] = parts[lastIndex] + ".json"
        path := parts join(File separator)
        if(root getChild(path) exists?()) {
            return root getChild(path) path
        }
        for(subdir: File in root getChildren()) {
            if(subdir dir?() && subdir getChild(path) exists?()) {
                return subdir getChild(path) path
            }
        }
        null    
    }

    getModuleFilenames: func ~entry -> ArrayList<String> {
        names := ArrayList<String> new()
        for(dir in root getChildren()) {
            if(dir file?() && dir name endsWith?(".json")) {
                name := dir name
                names add(name substring(0, name length() - 5))
            }
            else names addAll(getModuleFilenames(dir))
        }
        names
    }

    getModuleFilenames: func (dir: File) -> ArrayList<String> {
        // first, get all that we have here. Let's say "*.json" is a module.
        names := ArrayList<String> new()
        for(child in dir getChildren()) {
            if(child file?() && child name endsWith?(".json")) {
                childName := child name
                names add(childName substring(0, childName length() - 5))
            }
        }
        // now, get all subdirectories.
        for(child in dir getChildren()) {
            if(child dir?()) {
                childName := child name
                for(name in getModuleFilenames(child)) {
                    names add("%s/%s" format(childName, name))
                }
            }
        }
        return names
    }

    getAllModules: func {
        for(name in getModuleFilenames()) {
            getModule(name)
        }
    }
}
