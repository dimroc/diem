initSidebarItems({"enum":[["Attribute",""],["AttributeValue","Attributes"],["ConditionKind","Conditions"],["ExpData","The type of expression data."],["Operation",""],["PropertyValue","The value of a property."],["QuantKind",""],["SpecBlockTarget","Describes the target of a spec block."],["TraceKind",""],["Value",""]],"struct":[["Condition",""],["Exp","An internalized expression. We do use a wrapper around the underlying internement implementation variant to ensure a unique API (LocalIntern and ArcIntern e.g. differ in the presence of the Copy trait, and by wrapping we effectively remove the Copy from LocalIntern)."],["ExpDisplay","Helper type for expression display."],["GlobalInvariant","Describes a global invariant."],["LocalVarDecl",""],["ModuleName","Names"],["ModuleNameDisplay","A helper to support module names in formatting."],["OperationDisplay","Helper type for operation display."],["QualifiedSymbol",""],["QualifiedSymbolDisplay","A helper to support qualified symbols in formatting."],["Spec","Specification and properties associated with a language item."],["SpecBlockInfo","Information about a specification block in the source. This is used for documentation generation. In the object model, the original locations and documentation of spec blocks is reduced to conditions on a `Spec`, with expansion of schemas. This data structure allows us to discover the original spec blocks and their content."],["SpecFunDecl",""],["SpecVarDecl","Declarations"]],"type":[["MemoryLabel","A label used for referring to a specific memory in Global and Exists expressions."],["PropertyBag","Specifications"],["TempIndex","Expressions"]]});