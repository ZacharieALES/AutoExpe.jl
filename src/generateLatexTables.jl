include("struct.jl")

"""
Create a latex table from the results of an autoexperiment. 

The lines of the latex table corresponds to the different possible values of the variables contained in rowVariables (obtained from argument tableStructure).
The columns of the latex table corresponds to variable columnVariables (idem).
"""
function createTexTables(parameters::ExpeParameters; compileTexFile::Bool=true, generateCSVOutput::Bool=true)

    outputFile = parameters.latexOutputFile    
    
    outputstream = open(outputFile, "w")
    println(outputstream, documentHeader())

    csvOutputFile = IOStream(string())
    if generateCSVOutput
        csvOutputFile = replace(parameters.latexOutputFile, ".tex" => ".csv")
        csvOutputstream = open(csvOutputFile, "w")
    end 

    tableConstructed = false

    if length(parameters.latexFormatPath) == 0
        println(Dates.format(now(), "yyyy/mm/dd - HHhMM:SS"), " Warning: there is no latex table specified (i.e., the argument \"latexFormatPath\" of the json file is empty).")
    end
    for tableStructure in parameters.latexFormatPath
        println(Dates.format(now(), "yyyy/mm/dd - HHhMM:SS"), "\t\t\t Creating table from ", tableStructure)

        if isfile(tableStructure)
            isValid = createTexTable(parameters, tableStructure, outputstream, csvOutputstream)
            if isValid
                tableConstructed = true
            end
        else
            println("Warning: the table ", tableStructure, " does not exist.")
        end 
    end

    println(outputstream, documentFooter()) 
    close(outputstream)
    close(csvOutputstream)

    if compileTexFile && tableConstructed

        outputFolder = dirname(outputFile)
        if length(outputFolder) == 0
            read(`pdflatex $outputFile`)
        else
            read(`pdflatex --output-directory $outputFolder $outputFile`)
        end
    end
    
    return nothing
end

"""
Create a latex table from the results of an autoexperiment. 

The lines of the latex table corresponds to the different possible values of the variables contained in rowVariables (obtained from argument tableStructure).
The columns of the latex table corresponds to variable columnVariables (idem).
"""
function createTexTable(parameters::ExpeParameters,  tableStructureFilePath::String, outputstream::IOStream, csvOutputStream::IOStream)

    generateCSVOutput = csvOutputStream != IOStream(string())
    
    # Get the table format (i.e., structure and features of the table)
    tableParam, rowVariables, columns = readLatexFormat(tableStructureFilePath)
    
    # Get all the results
    # results[i] is one dictionary representing all information obtained from one resolution
    results = Vector{Dict{String, Any}}(getResults(parameters))

    # tableCombinations[i]::CombinationResults: all results used to compute values in row(s) of combination n°i
    # (i.e., results which correspond to the combination of values of the row variables used in row n°i of the table)
    tableCombinations = splitResultsByCombination(parameters, tableParam, results, columns, rowVariables)

    # If none of the row variables has a value in the result files, do not create the table
    if tableCombinations == nothing
        return false
    end
    
    # Compute the values displayed in the table
    computeTableValues(parameters, tableParam, tableCombinations, columns)

    containColumnGroups = false

    # Check if there is a ColumnGroup
    for column in columns
        if typeof(column) == ColumnGroup
            containColumnGroups = true
        end
    end

    # Create the table header to the latex file
    tableHeader, csvHeader = createTableHeader(tableParam, rowVariables, columns, containColumnGroups)

    if generateCSVOutput
        println(csvOutputStream, csvHeader)
    end
    
    # Count the number of rows to split the table if it reaches tableParam.maxRowsInATable
    rowCount = 1

    if containColumnGroups
        rowCount = 2
    end

    mustReprintHeader = true
    tableHasMissingValues = false
    
    # For each CombinationResults (i.e., each combination of row parameters)
    for combinationId in 1:length(tableCombinations)

        combinationResults = tableCombinations[combinationId]

        # Value of the row variables which are different from the previous row
        latexModifiedRowVariables = ""

        # Value of all the row variables
        latexAllRowVariables = ""
        latexAllRowVariablesCSV = ""
        
        # For each row variable
        for i in 1:length(rowVariables)

            # Get its value in the current combination
            displayedValue = combinationResults.combination[i]

            # If it is a numerical value
            numValue = numericalValue(displayedValue)

            if numValue != nothing
                numValue *= rowVariables[i].multiplier # Multiply it
                if rowVariables[i].digits != -1 # Round it if required
                    if rowVariables[i].digits == 0
                        numValue = round(Int, numValue)
                    else
                        numValue = round(numValue, digits = rowVariables[i].digits)
                    end 
                end
                displayedValue = numValue
            end

            latexAllRowVariables *= string(displayedValue) * " & "
            latexAllRowVariablesCSV *= string(displayedValue) * ","
            
            if combinationId > 1 && combinationResults.combination[i] != tableCombinations[combinationId-1].combination[i]     
                latexModifiedRowVariables *= string(displayedValue)
            end
            
            latexModifiedRowVariables *=  " & "
        end

        latexRow = ""
        
        # If the table represents the mean value over all instances 
        if !tableParam.expandInstances

            if generateCSVOutput
	        print(csvOutputStream, latexAllRowVariablesCSV)
            end
            if mustReprintHeader
                latexRow = latexAllRowVariables
            else 
                latexRow = latexModifiedRowVariables
            end 

            rowCount, mustReprintHeader, tableHasMissingValues = addResultsToRow(combinationResults.displayedValues, mustReprintHeader, outputstream, csvOutputStream, tableHeader, latexRow, rowCount, tableHasMissingValues, tableParam, containColumnGroups)
            
        else # If the result of each instance is on a different line

            instancesName = collect(keys(combinationResults.instancesResults))
            
            # For each instance
            for instanceId in 1:length(instancesName)
                latexRow = ""
                if mustReprintHeader
                    latexRow *= latexAllRowVariables
                elseif instanceId == 1
                    latexRow *= latexModifiedRowVariables
                else
                    latexRow *= "&"^length(rowVariables)
                end

                # TODO: remove extension according to tableParam.hideInstancesExtension
                instanceName = basename(instancesName[instanceId])
                instanceName = replace(instanceName, "_" => "\\_")
                latexRow *= instanceName * " & "

                if generateCSVOutput
		    print(csvOutputStream, latexAllRowVariablesCSV * instanceName * ",")
		end

                instanceResults = combinationResults.instancesResults[instancesName[instanceId]]
                
                rowCount, mustReprintHeader, tableHasMissingValues = addResultsToRow(instanceResults.displayedValues, mustReprintHeader, outputstream, csvOutputStream, tableHeader, latexRow, rowCount, tableHasMissingValues, tableParam, containColumnGroups) 
            end
        end

        if length(combinationResults.clineColumns) == 2 && !mustReprintHeader
            println(outputstream, "\\cline{" * string(combinationResults.clineColumns[1]) * "-" * string(combinationResults.clineColumns[2]) * "}")
        end 
    end

    ## Print the sum of the numerical columns
    if mustReprintHeader
        println(outputstream, tableHeader)
    end

    print(outputstream, "&"^(length(rowVariables)-1))

    if tableParam.expandInstances
        print(outputstream, "&")
    end
    
    # For each column
    allColumnsConsidered = false
    colId = 1
    columnsSum = Vector{Float64}([])
    columnsCount = Vector{Float64}([])
    columnsHaveNumericalValues = Vector{Bool}([])
    
    for combinationId in 1:length(tableCombinations) # For each result row

        combinationResults = tableCombinations[combinationId]

        for (path, instanceResults) in combinationResults.instancesResults # For each instance

            for (colId, colResults) in enumerate(instanceResults.computedResults) # For each column

                numValues = numericalVector(colResults)

                if length(columnsSum) < colId
                    append!(columnsSum, zeros(colId - length(columnsSum)))
                    append!(columnsCount, zeros(colId - length(columnsCount)))
                    append!(columnsHaveNumericalValues, zeros(colId - length(columnsHaveNumericalValues)))
                end

                if length(numValues) > 0
                    columnsSum[colId] += sum(numValues) 
                    columnsCount[colId] += 1
                    columnsHaveNumericalValues[colId] = true
                end 
            end # for each column
        end # for each instance
    end # for each result row

    println(outputstream,  " \\textbf{Total} & ")
    for (colId, colSum) in enumerate(columnsSum)
        if columnsHaveNumericalValues[colId]
            
            if colSum > typemax(Int)
                colSum = typemax(Int)
            elseif colSum < typemin(Int)
                colSum = typemin(Int)
            end 
            if round(Int, colSum) != colSum && abs(colSum) < 10
                print(outputstream, round(colSum, digits=2))
            else 
                print(outputstream, round(Int, colSum))
            end 
        end 
        print(outputstream, " & ") 
    end

    println(outputstream, "\\\\\n")
    
    println(outputstream,  " & \\textbf{Average} & ")
    for (colId, colCount) in enumerate(columnsCount)
        if columnsHaveNumericalValues[colId]
            averageValue = columnsSum[colId] / Float64(colCount)
            if round(Int, averageValue) != averageValue && abs(averageValue) < 10
                print(outputstream, round(averageValue, digits=2))
            else 
                print(outputstream, round(Int, averageValue))
            end 
        end 
        print(outputstream, " & ") 
    end 

    println(outputstream, "\\\\\n",  getTableFooter(tableParam.caption, hasMissingValues=tableHasMissingValues))
    
    return true
end


function getTableFooter(caption::String; hasMissingValues::Bool=false)
    tableFooter = raw"""\hline\end{array}$}

    """ * caption * "\n"

    if hasMissingValues
        tableFooter *= raw""" The symbol $\dag$ indicates an average value   computed from an incomplete set of results compared to other values on the same line."""
    end 

    tableFooter *= raw"""\end{center}
    \newpage

    """

    return tableFooter 
end

"""
Unique name of a column used to identify a column without any ambguity.
Required since several columns may have the same displayed name in the latex table.
"""
function uniqueColumnName(col::Column)
    result = col.columnName * "-" 

    if col.computeValue != emptyFunction
        result *= String(Symbol(col.computeValue)) * "("
    end 

    for valId in 1:length(col.valInfos)
        val = col.valInfos[valId]
        result *= val.key

        if length(val.indexes) > 0
            result *= "["
            for indexId in 1:length(val.indexes)
                result *=  string(val.indexes[indexId])

                if indexId != length(val.indexes)
                    result *= ","
                end 
            end
            result *= "]"
        end

        result *= " from method " * val.resolutionMethod

        if valId != length(col.valInfos)
            result *= ", "
        end 
    end
    
    if col.computeValue != emptyFunction
        result *= ")"
    end 

    return result 
end


"""
For each row variable, get all its values which appear in the results

Intput
- variables: list of RowVariables
- results: dictionary in which each entry corresponds to a result

Output
- array which contains one vector for each variable. The array associated to a variable contains all its possible values
"""
function getVariablesValues(rowVariables::Vector{RowVariable}, results::Vector{Dict{String, Any}}, expeParameters::ExpeParameters)

    # Different values of all the row variables
    variablesValues = Vector{Vector{Any}}([])

    # Add an empty array for each row variable
    for var in 1: length(rowVariables)
        push!(variablesValues, [])
    end     

    # For each result 
    for result in results

        # For each RowVariable considered
        for rvId in 1:length(rowVariables)
            rvKey = rowVariables[rvId].valInfo.key

            # If the result contains this variable
	    if haskey(result, rvKey)
	    
                normalizedValue = numericalValue(result[rvKey])

		# If the value is not numerical
		if normalizedValue == nothing
		    normalizedValue = result[rvKey]
		else
		    result[rvKey] = normalizedValue
		end
	    
	        # If its value in this result is new, add it
		if !(normalizedValue in variablesValues[rvId])

                    # If the variable is not part of the parameters of the experiment or if its value in the result is included in the values considered in the experiment
                    # (if the user specify values for a parameter in the experiment, we only want to include in the table results for these values)
                    if !haskey(expeParameters.parametersToCombine, rvKey) || normalizedValue in expeParameters.parametersToCombine[rvKey] || result[rvKey] in expeParameters.parametersToCombine[rvKey]
                        push!(variablesValues[rvId], normalizedValue)
                    end
		end
            end 
        end 
    end
    
    # Sort each array
    for rvId in 1:length(rowVariables)

        # If the row variable only contains integer values, set its number of displayed digits to 0
        isIntRowVariable = true

        valueId = 1

        while isIntRowVariable && valueId < length(variablesValues[rvId])

	    numV = numericalValue(variablesValues[rvId][valueId])
            if typeof(numV) == Int
	        variablesValues[rvId][valueId] = numV
	    else
                isIntRowVariable = false
            end
            valueId += 1
        end

        try
            variablesValues[rvId] = sort(variablesValues[rvId])
            if isIntRowVariable
                rowVariables[rvId].digits = 0
            end 
	catch e
	    println("Warning: unable to sort the following values of row variable ", rowVariables[rvId].displayedName, "\n\tvalues: ", variablesValues[rvId])
	end
    end

    return variablesValues

end     

"""
Compute the mean value of the numerical values contained in an array
Returns nothing if there are no numerical value in the array.
"""
function mean(t::Vector{Any})

    numT = numericalVector(t)
    
    if length(numT) > 0
        return sum(numT)/length(numT)
    else
        println("Warning: unable to compute the mean value of a vector without any numerical values (vector: ", t, ")")
        return nothing
    end
end

"""
Compute the gap of the two numerical values included in an array (|t[1] - t[2]|/t[1]).
Returns nothing if:
- the size of the array is not 2;
- both values are not numerical.

Note:
- to avoid dividing by 0, 1E-6 is added to the denominator;
- to avoid very high gaps, the denominator is set to 0.1 if it is <0.1 and if the gap exceeds 1000.
"""
function gap(t::Vector{Any})

    numT = numericalVector(t)
    
    if length(t) == 2
        numerator = abs(t[1] - t[2])
        denominator = abs(t[1])

        result = 100 * numerator / (denominator + 1E-6)

        if result > 1000 && denominator < 0.1
            println("Warning: gap over 1000 found with a denominator < 0.1. Setting the denominator to 0.1 to avoid huge gap values (numerator: ", numerator, ", initial denominator: ", denominator, ")") 
            result = 100 * numerator / 0.1
        end

        return result
    else
        println("Warning: a gap must be computed between two numerical values but you entered ", length(t), " values instead: gap(", t, ")")
    end

    return nothing
end

"""
Convert a vector into numerical values. Unexpected value are ignored (e.g., non numerical values, arrays, strings, ...)
"""
function numericalVector(v::Vector{Any}; displayWarning::Bool=true)
    result = Vector{Any}()

    for element in v
        numElement = numericalValue(element)

        if numElement != nothing
            push!(result, numElement)
        else
            println("Warning: unable to convert \"", element, "\" into a numerical value. Value skipped.")
        end 
    end

    return result
end 

"""
Parse a value from a result file into a numerical value:
- convert the strings which represent integers and floats; and
- returns nothing for unexpected values.
"""
function numericalValue(v)

    if isa(v, Array)
        return nothing
    else
        intValue = nothing
        floatValue = nothing
        try
            intValue = tryparse(Int, v)
        catch e
            if typeof(v) == Int
                intValue = v
            end 
        end
        
        try
            floatValue = tryparse(Float64, v)
        catch e
            if typeof(v) == Float64
                floatValue = v
            end 
        end

        if intValue == nothing || (floatValue != intValue && floatValue != nothing)
            return floatValue
        else
            return intValue
        end
    end 
end


"""
Header of the latex document
"""
function documentHeader()
    return raw"""
\documentclass{article}

\usepackage[french]{babel}
\usepackage [utf8] {inputenc} % utf-8 / latin1
\usepackage{amsmath}
\usepackage{multicol}
\usepackage{multirow}
\usepackage{graphicx}
\usepackage[landscape,a3paper, total={40cm, 28cm}]{geometry}

\begin{document}
\renewcommand{\arraystretch}{1.4}
"""
end 

"""
Footer of the latex document
"""
function documentFooter()
    return raw"""
\end{document}
%%% Local Variables:
%%% mode: latex
%%% TeX-master: t
%%% End:
"""
end

"""
Read the format of a latex table from a json file
"""
function readLatexFormat(jsonFilePath::String)

    tableParam = TableParameters()
    rows = Vector{RowVariable}()

    # Contains either Column or ColumnGroup
    columns = Vector{Any}()
    
    stringdata=join(readlines(jsonFilePath))
    formatArray = JSON.parse(stringdata)

    # For each entry (row, column or table parameters) in the format
    for entry in formatArray

        # If the entry corresponds to the table parameters
        if haskey(entry, "caption")
           
            tableParam.caption = entry["caption"]

            if haskey(entry, "maxRowsInATable")
                numValue = numericalValue(entry["maxRowsInATable"])
                if numValue != nothing
                    tableParam.maxRowsInATable = numValue
                else
                    println("Warning: The maximum number of rows in a table (\"maxRowsInATable\") must be a numerical value. The value is ignored.\n\tCurrent value: ", entry["maxRowsInATable"])
                end 
            end
            
            if haskey(entry, "expandInstances")
                tableParam.expandInstances = entry["expandInstances"]
            end 
            
            if haskey(entry, "hideInstancesExtension")
                tableParam.hideInstancesExtension = entry["hideInstancesExtension"]
            end 

            if haskey(entry, "leftVline")
                tableParam.leftVline = entry["leftVline"]
            end 
            
            if haskey(entry, "rightVline")
                tableParam.rightVline = entry["rightVline"]
            end 
            
            if haskey(entry, "vlineAfterRowParams")
                tableParam.vlineAfterRowParams = entry["vlineAfterRowParams"]
            end

            if haskey(entry, "maxNonScientificValue")
                numValue = numericalValue(entry["maxNonScientificValue"])
                if numValue != nothing
                    tableParam.maxNonScientificValue = numValue
                else
                    println("Warning: The maximum number of rows in a table (\"maxNonScientificValue\") must be a numerical value. The value is ignored.\n\tCurrent value: ", entry["maxNonScientificValue"])
                end 
            end 
           
        # If the entry corresponds to a row
        elseif haskey(entry, "rowParameterName")

            parameterName = entry["rowParameterName"]

            # If the parameter is obtained from an array, get its indice(s)
            indexes = nothing
            invalidIndexes = Vector{Any}() 
            if haskey(entry, "indexes")

                if !(entry["indexes"] <: Vector)
                    entry["indexes"] = [entry["indexes"]]
                end

                indexes = Vector{Int}()

                for index in entry["indexes"]
                    
                    numValue = numericalValue(index)
                    
                    if numValue == nothing
                        push!(invalidIndexes, index)
                    else
                        push!(indexes, numValue)
                    end 
                end 
            end

            # If the row parameter does not have any invalid index
            if length(invalidIndexes) == 0
                
                if indexes == nothing
                    vi = ValueInformation(parameterName)
                else
                    vi = ValueInformation(parameterName, indexes=indexes)
                end
                
                displayedName = vi.key
                
                # If the name displayed is different from the parameter name
                if haskey(entry, "displayedName")
                    displayedName = entry["displayedName"]
                end

                hline = haskey(entry, "hline") && entry["hline"]
                rowVar = RowVariable(vi, hlineBetweenValues=hline, displayedName=displayedName)
                
                if haskey(entry, "multiplier") && numericalValue(entry["multiplier"]) != nothing
                    rowVar.multiplier = numericalValue(entry["multiplier"])
                end

                if haskey(entry, "digits") && numericalValue(entry["digits"]) != nothing
                    rowVar.digits = numericalValue(entry["digits"])
                end

                push!(rows, rowVar)
                
            else # If the parameter has invalid indexes
                println("Warning: The indexes of row parameters must be numerical values. The row parameter is ignored.\n\trow parameter name: ", parameterName, "\n\tInvalid indexes: ", invalidEntries)
            end 

        # If the entry corresponds to a column
        elseif haskey(entry, "columnParameters")

            column = readColumn(entry)

            if column != nothing
                push!(columns, column)
            end
            
        elseif haskey(entry, "columnGroupName") && haskey(entry, "columns")

            colGroup = ColumnGroup(entry["columnGroupName"], Vector{Column}())

            for columnEntry in entry["columns"]
                
                column = readColumn(columnEntry)

                if column != nothing
                    push!(colGroup.columns, column)
                end
            end
            
            if haskey(entry, "isBestValueMinimal")
                colGroup.isBestValueMinimal = entry["isBestValueMinimal"]
            end
            
            if haskey(entry, "vlineAfter")
                colGroup.vlineAfter = entry["vlineAfter"]
            end

            if haskey(entry, "highlightBestValue")
                colGroup.highlightBestValue = entry["highlightBestValue"]
            end

            push!(columns, colGroup)
            
        else
            println("Warning: the json array contains an element which is neither a table parameter, nor a column, nor a row, nor a column group:")
            println("\t- Each entry must be a json object which contains either the key(s) \"caption\", \"rowParameterName\", (\"columnParameters\" and \"method\") or  \"columnGroupName\";")
            println("\t- The value of key \"rowParameterName\", \"method\" and \"columnGroupName\" must be strings;")
            println("\t- The value of key\"columnParameters\" must be an array of objects. Each object must contain at least a key \"name\".")
            println("Element in the array: ", entry)
        end 
        
    end
    
    return tableParam, rows, columns
end

"""
Read the json entry which corresponds to a column and return the corresponding Column.
"""
function readColumn(dictColumn::Dict{String, Any})

    if !haskey(dictColumn, "columnParameters")
        println("Warning: the following input element does not correspond to a column (input: \"", displayStringDict(dictColumn), "\"). It must contain a key \"columnParameters\". The column is thus ignored.")
        return nothing
    end

    defaultResolutionMethod = ""
    
    if haskey(dictColumn, "method")
        defaultResolutionMethod = dictColumn["method"]
    end 
        
    parameters = dictColumn["columnParameters"]

    # If there is only one parameter
    if !(typeof(parameters) <: Vector)
        parameters = [parameters]
    end 

    viParameters = Vector{ValueInformation}()

    for parameter in parameters
        vi = nothing

        # If the column parameter is a dictionary
        if typeof(parameter) <: Dict
            if haskey(parameter, "name")
                vi = ValueInformation(parameter["name"])
                
                if !haskey(parameter, "method")
                    vi.resolutionMethod = defaultResolutionMethod 
                else
                    vi.resolutionMethod = parameter["method"] 
                end
                
                if haskey(parameter, "indexes")
                    vi.indexes = Vector{Int}()
                    
                    if isa(parameter["indexes"], Array)
                        for id in 1:length(parameter["indexes"])
                            value = parameter["indexes"][id]
                            if typeof(value) == Int
                                push!(vi.indexes, value)
                            else
                                numValue = numericalValue(value)
                                if numValue != nothing
                                    push!(vi.indexes,  round(Int, numValue))
                                end
                            end 
                        end
                    else
                        if parameter["indexes"] != nothing
                            push!(vi.indexes, round(Int, parameter["indexes"]))
                        end 
                    end 
                end
            else
                println("Warning: parameter without any key \"name\" or any key \"method\"")
                println("Parameter: ", displayStringDict(parameter))
                println("Column column: ", displayStringDict(dictColumn))
            end 
        elseif typeof(parameter) == String # If the parameter is a string
            vi = ValueInformation(parameter)
            vi.resolutionMethod = defaultResolutionMethod  
        end


        if vi != nothing
            if vi.resolutionMethod != ""
                push!(viParameters, vi)
            else
                println("Warning: unspecified resolution method for a column parameter (the parameter: ", parameter, "). You can add a field  \"method\"  either:\n- in the column parameter; or\n- in the column entry (it will be used by default for all columnParameters of this column with an unspecified resolution method).")
            end 
        else
            println("Warning: invalid format for a column parameter. The format must either be String or Dict.\n\tCurrent parameter: ", parameter, "\n\tCurrent type: ", typeof(parameter))
        end 
    end

    vline = haskey(dictColumn, "vline") && dictColumn["vline"]

    fct = emptyFunction

    if haskey(dictColumn, "function")    
        if dictColumn["function"] == "gap"
            fct = gap
        elseif dictColumn["function"] == "mean"
            fct = mean
        else
            println("Warning: unknown input function \"", functionString, "\".")         
        end 
    end

    column = Column(viParameters, vlineAfter=vline, computeValue=fct)

    if haskey(dictColumn, "displayedName")
        column.columnName = dictColumn["displayedName"]
    end

    if haskey(dictColumn, "multiplier") && numericalValue(dictColumn["multiplier"]) != nothing
        column.multiplier = numericalValue(dictColumn["multiplier"])
    end

    if haskey(dictColumn, "digits") && numericalValue(dictColumn["digits"]) != nothing
        column.digits = numericalValue(dictColumn["digits"])
    end

    if haskey(dictColumn, "prefix")
        column.prefix = dictColumn["prefix"]
    end

    if haskey(dictColumn, "suffix") 
        column.suffix = dictColumn["suffix"]
    end

    if haskey(dictColumn, "ignoreBold") 
        column.ignoreBold = dictColumn["ignoreBold"]
    end

    return column

end 

"""
Get all the results computed in the experiment
"""
function getResults(parameters::ExpeParameters)
    
    # Variable which contains all the results of all instances
    # Each result is a Dict which contains:
    # - one entry with the key "method"
    # - one entry for each parameter
    # - one entry for each result
    results = Vector{Dict{String, Any}}()
    
    for instancePath in parameters.instancesPath

        instanceName = splitext(basename(instancePath))[1]   
        outputFile = parameters.outputPath * "/" * instanceName * ".json"
        
        # Get the results previously computed for this instance if any
        if isfile(outputFile)
            stringdata=join(readlines(outputFile))

            try
                instanceResults = Vector{Dict{String, Any}}(JSON.parse(stringdata))

                for result in instanceResults
                    result["auto_expe_instance_path"] = instancePath
                end
                
                append!(results, instanceResults)
            catch e
                println("Error: Unable to read result file: ", outputFile)
                print(e)
            end
        end
    end 
    return results
end 

"""
Split all the results according to their combination of parameters

Input
- parameters: parameters of the experiment;
- results: all the results saved during the experiment;
- columns: the columns of the table;
- rowVariables: the row variables of the table.

Output
- an array of CombinationResults ordered according to the row of the table (i.e. the ith index of this array corresponds to all the results used to compute the ith line)
"""
function splitResultsByCombination(parameters::ExpeParameters, tableParam::TableParameters, results::Vector{Dict{String, Any}}, columns::Vector{Any}, rowVariables::Vector{RowVariable})

    # For each row variable, get all its possible values
    # rowValues[i] is an array including all the values of the ith row variable in rowVariables
    rowValues = getVariablesValues(rowVariables, results, parameters)

    for rowVariableId in length(rowVariables):-1:1
        
        if length(rowValues[rowVariableId]) == 0
            println("Warning: No value found for variable ", rowVariables[rowVariableId].valInfo.key, ". This variable is ignored.")
            deleteat!(rowVariables, rowVariableId)
            deleteat!(rowValues, rowVariableId)
        end 
    end

    ## Get the number of result columns
    resultColumnsCount = 0
    
    # For each column
    for column in columns

        if typeof(column) == ColumnGroup
            for col in column.columns
                resultColumnsCount += 1 
            end
        else
            resultColumnsCount += 1 
        end
    end 
    
    # Index in rowValues of the value of all row parameters in the current combination
    # ex: if combinationIds = [3, 4] the current line corresponds to the value rowValues[1][3] and rowValues[2][4]
    combinationIds = Vector{Int}(ones(length(rowVariables)))
    previousCombinationIds = Vector{Int}(-ones(length(rowVariables)))
    isOver = false

    tableCombinations = Vector{CombinationResults}()
    
    # While all the combinations have not been considered
    while !isOver

        combinationResults = Vector{Dict{String, Any}}()
        
        ## Get all the result for this combination

        # For each result
        for result in results
            
            isResultInThisCombination = true
            checkId = 1

            # While all the row variables have not all been checked
            while isResultInThisCombination && checkId <= length(rowVariables)
                
                # If the result does not have a value for row variable checkId or if its value is not equal to its value in the current line
                if !haskey(result, rowVariables[checkId].valInfo.key) || result[rowVariables[checkId].valInfo.key] != rowValues[checkId][combinationIds[checkId]]
                    isResultInThisCombination = false
                end

                checkId += 1
            end

            # If the result is in the current combination
            if isResultInThisCombination
                push!(combinationResults, result)
            end
        end

        parametersValues = Vector{Any}()

        for i in 1:length(combinationIds)
            push!(parametersValues, rowValues[i][combinationIds[i]])
        end
         
       push!(tableCombinations, CombinationResults(parameters, parametersValues, combinationResults))

        # Get the next combination of row parameters
        varId = length(rowVariables)
        nextCombinationFound = false

        for i in 1:length(combinationIds)
            previousCombinationIds[i] = combinationIds[i]
        end

        if length(rowVariables) == 0
            isOver = true
        end 

        while !nextCombinationFound && !isOver

            # If the id of variable varId can be incremented
            if combinationIds[varId] < length(rowValues[varId])

                # Increment it
                combinationIds[varId] += 1
                nextCombinationFound = true

                if rowVariables[varId].hlineBetweenValues
                    lineWidth = resultColumnsCount + length(rowVariables)

                    if tableParam.expandInstances
                        lineWidth += 1
                    end
                    
                    tableCombinations[end].clineColumns = Vector{Int}([varId, lineWidth])
                end

            # If variable varId cannot be incremented
            else
                # If we reached the last combination
                if varId == 1
                    isOver = true
                else
                    # Try to increment the id of the previous variable
                    combinationIds[varId] = 1
                    varId -= 1
                end
            end
        end
    end

    return tableCombinations
end 


"""
Compute the value for each result column for each CombinationResults
"""
function computeTableValues(parameters::ExpeParameters, tableParameters::TableParameters, combinationResults::Vector{CombinationResults}, columns::Vector{Any})
    
    # For each combination
    for combination in combinationResults

        # For each column
        columnId = 1 # Id of the column in InstanceResults.computedResults (i.e., 1 id per columns in the table)
        columnsId = 1 # Id of the column or the group in "columns" (i.e., 1 id per groups and ungrouped columns)
        groupId = 1 # If columns[columnsId] is a ColumnGroup, id of the current column in the group (ignored otherwise)

        column = columns[columnsId]
        if typeof(column) == ColumnGroup
            column = column.columns[1]
        end
        
        allColumnsConsidered = false

        while !allColumnsConsidered

            # For each instance
            for (instanceName, instanceResults) in combination.instancesResults

                instanceResults.instancePath = instanceName
                
                # Compute the column values for this instance and add them in instanceResults.computedResults
                computeInstanceValues(parameters, instanceResults, column)

                # If the table displays one row for each instance 
                if tableParameters.expandInstances

                    if length(instanceResults.computedResults) == 0
                        emptyValue = TableValue(nothing, false, false, 1, column)
                        push!(instanceResults.displayedValues,  emptyValue)
                    else
                        meanValue, isNumerical = computeTableValue(parameters, instanceResults.computedResults[end], column)
                        missingResultsForValue = hasMissingResults(column, instanceResults)
                        push!(instanceResults.displayedValues, TableValue(meanValue, isNumerical, missingResultsForValue, tableParameters.maxNonScientificValue, column))
                    end 
                end 
            end

            # If the table display the mean value over all the instances
            if !tableParameters.expandInstances

                # Get all the values over all the instances in one vector
                allInstancesResults = Vector{Any}()
                missingResultsForValue = false

                for (instanceName, instanceResults) in combination.instancesResults
                    append!(allInstancesResults, instanceResults.computedResults[end])
                    if hasMissingResults(column, instanceResults)
                        missingResultsForValue = true
                    end 
                end

                meanValue, isNumerical = computeTableValue(parameters, allInstancesResults, column)
                push!(combination.displayedValues, TableValue(meanValue, isNumerical, missingResultsForValue, tableParameters.maxNonScientificValue, column))
            end 
            
            ## Get the next column to process

            # Do we go to the next id in array columns?
            setNextColumn = false
            
            if typeof(columns[columnsId]) == ColumnGroup
                if groupId == length(columns[columnsId].columns)
                    if columnsId == length(columns)
                        allColumnsConsidered = true
                    else 
                        setNextColumn = true
                    end 
                else
                    groupId += 1
                    column = columns[columnsId].columns[groupId]
                end 
            else
                if columnsId == length(columns)
                    allColumnsConsidered = true
                else
                    setNextColumn = true
                end 
            end

            # If this is the end of a group
            if typeof(columns[columnsId]) == ColumnGroup && (setNextColumn || allColumnsConsidered)
                group = columns[columnsId]

                # If the best values of the group must be highlighted
                if group.highlightBestValue
                    if !tableParameters.expandInstances
                        setBoldValuesInGroup(group, combination.displayedValues[columnId-length(group.columns)+1:columnId])         
                    else
                        for (instanceName, instanceResults) in combination.instancesResults
                            setBoldValuesInGroup(group, instanceResults.displayedValues[columnId-length(group.columns)+1:columnId])
                        end 
                    end 
                end 
            end
            
            if setNextColumn

                columnsId += 1
                column = columns[columnsId]
                if typeof(column) == ColumnGroup
                    groupId = 1
                    column = column.columns[groupId]
                end
            end

            columnId += 1
        end # while !allColumnsConsidered
    end # for combination in combinationResults
end 


"""
Compute the value in column "column" for an instance using the results of the methods in "methodResults".
methodResults only contains 1 entry for each resolution method required to compute the value of the column.

Input
- column: the column in which the result must be computed
- methodResults: dictionary of results for the considered instance indexed by method name
  methodResults[methodName][resultName]: value of entry "resultName" in the result files for method "methodName"
"""
function computeValue(column::Column, methodResults::Dict{String, Dict{String, Any}}, instancePath::String)
        
    # Values used to compute the value in the column
    values = Vector{Any}()
    unavailableInformation = Vector{ValueInformation}([])
    
    # For each information required to compute the value of the column
    for valInfo in column.valInfos

        methodResult = methodResults[valInfo.resolutionMethod]
        if !haskey(methodResult, valInfo.key)
            push!(unavailableInformation, valInfo)
        else
            
            parameter = methodResult[valInfo.key]

            # Number of dimensions expected in the array
            parameterDimension = length(valInfo.indexes)

            value = parameter 

            # If no dimensions are specified
            if valInfo.indexes == []

                # For each array dimension of the parameter, take the first value
                for dimId in 1:parameterDimension
                    if isa(value, Array)
                        value = selectdim(value, 1, 1)
                    end 
                end
            else
                indexesDimension = length(valInfo.indexes)

                if indexesDimension != parameterDimension
                    print("Warning: ", indexesDimension, " dimensions are specified for parameter \"", valInfo.key, "\" used to compute the value of column \"", column.columnName, "\". However, this parameter contains ", parameterDimension, " dimensions.")

                    if indexesDimension > parameterDimension
                        println(" Ignoring the additional indexes.")
                    else
                        println(" Index 1 is considered for the unspecified dimensions.")
                    end 
                end 

                # Select the indexes for the minimum of both dimensions
                for dimId in 1:min(indexesDimension, parameterDimension)
                    value = selectdim(value, 1, indexesDimension[dimId])
                end

                # If the parameter dimension is greater, select index 1 for the next dimensions
                for dimId in min(indexesDimension, parameterDimension)+1:parameterDimension
                    value = selectdim(value, 1, 1)
                end
            end
            push!(values, value)  
        end 
    end

    computedValue = nothing

    if length(unavailableInformation) > 0
        print("Warning: missing entries to compute the value of the column named \"", uniqueColumnName(column), "\"\n\tList of the ", length(unavailableInformation), " missing entries:")
        for valInfo in unavailableInformation
            print("\"", valInfo.key, "\" for method \"", valInfo.resolutionMethod, "\", ")
        end
        println("\n\tList of the available results: ", methodResults, "\n\tInstance Path: ", instancePath)
    else
        if column.computeValue != emptyFunction
            computedValue = column.computeValue(values)
        elseif length(values) == 0
            println("Warning: no value obtained for a cell in column ", uniqueColumnName(column), ".")
        else
            computedValue = values[1]
            if length(values) > 1
                println("Warning: more than one values obtained for a cell in column ", uniqueColumnName(column), ": ", values, ". Only keeping the first one")
            end 
        end
    end 

    return computedValue
end 

"""
Compute all the values for an instance and a combination in a column.
There can be several of these values.
E.g.: If we have results when combining two parameters in a knapsack problem: 
1 - number of knapsacks: 2 and 3;
2 -  size of the:  10 and 20.

We get 4 combinations of parameters: (2, 10), (3, 10), (2, 20), (3, 20).

If we create a latex table in which:
- the number of knapsacks is a row parameter;
- the size of the knapsacks is not;
for each instance we will obtain two result lines: 2 and 3.
For each of these lines we will have 2 values (2, 10) and (2, 20) in the first and (3, 10) and (3, 20) in the second.

Input
- parameters: the parameters of the experiment;
- instanceResults: results obtained during this experiment for the instance and the combination considered;
- column: the column for which we compute the values.
"""
function computeInstanceValues(parameters::ExpeParameters, instanceResults::InstanceResults, column::Column)

    # Get all the resolution methods required to compute the value in column "column"
    vResolutionMethods = Vector{String}()

    for val in column.valInfos
        if !(val.resolutionMethod in vResolutionMethods)
            push!(vResolutionMethods, val.resolutionMethod)
        end 
    end

    # Represents all the values computed for this instance
    instanceComputedResults = Vector{Any}()

    # If the first resolution method required to compute values in this column does not have any result
    if haskey(instanceResults.methodResults, vResolutionMethods[1])
        
        # For each result obtained for this instance for the first resolution method
        for methodResult in instanceResults.methodResults[vResolutionMethods[1]].results

            ## Check if there is a result with the same value of parameters for all the other resolution methods required to compute the value in this column

            # Dictionary of compatible results used to compute a value in the column
            # methodResults[methodName][resultName]: value of the entry "resultName" for the method "methodName"
            methodResults = Dict{String, Dict{String, Any}}()
            methodResults[vResolutionMethods[1]] = methodResult

            methodId = 2
            missingMethod = false

            # While all the methods have not been tested and no method result is missing yet
            while methodId <= length(vResolutionMethods) && !missingMethod

                currentMethodName = vResolutionMethods[methodId]
                currentMethodResults = instanceResults.methodResults[currentMethodName]

                resultFound = false
                resultId = 1
                
                # While:
                # - all the results of the current method have not been tested; and
                # - a compatible result has not been found.
                while resultId <= length(currentMethodResults.results) && !resultFound

                    currentResult = Dict{String, Any}(currentMethodResults.results[resultId])

                    # If this result corresponds to the same parameters than the result of the first method
                    isResultValid = true
                    parameterId = 1

                    parametersNames = collect(keys(parameters.parametersToCombine))

                    while parameterId < length(parametersNames) && isResultValid
                        parameterName  = parametersNames[parameterId]

                        if !haskey(currentResult, parameterName)
                            isResultValid = false
                        else
                            parameterValue = currentResult[parameterName]
                            referenceValue = methodResult[parameterName]

                            if parameterValue != referenceValue
                                isResultValid = false
                            end 
                        end 

                        parameterId += 1
                    end

                    if isResultValid
                        resultFound = true
                        methodResults[currentMethodName] = currentResult
                    end 
                    resultId += 1
                end

                if !resultFound
                    missingMethod = true
                end 

                methodId += 1
            end
            
            # If compatible results have been found for all the resolution methods required
            if !missingMethod

                # Compute the corresponding values and add them to the instance results
                value = computeValue(column, methodResults, instanceResults.instancePath)

                if value != nothing
                    append!(instanceComputedResults, value)
                end
            end 
        end # for methodResult in instanceResults.methodResults[vResolutionMethods[1]]
    end 

    push!(instanceResults.computedResults, instanceComputedResults)

end 

"""
Compute the average value of a vector of results
"""
function computeTableValue(parameters::ExpeParameters, results::Vector{Any}, column::Column)

    numericalResults = numericalVector(results)
    
    isNumerical = true

    if length(numericalResults) > 0
        
        meanValue = sum(numericalResults) / length(numericalResults)
        meanValue *= column.multiplier
        
        if column.digits == 0
            if meanValue > typemax(Int)
                meanValue = typemax(Int)
            elseif meanValue < typemin(Int)
                meanValue = typemin(Int)
            end 
            return round(Int, meanValue), isNumerical
        else
            return round(meanValue, digits=column.digits), isNumerical
        end
    else
        isNumerical = false
        filteredValues = unique(results)
        if length(filteredValues) == 1
            if filteredValues[1] != nothing
                return filteredValues[1], isNumerical
            else
                return nothing, isNumerical
            end 
        else
            return nothing, isNumerical
        end 
    end        
end



"""
Find the best numerical values in the set of values of a group and set them to bold.
Non-numerical values are ignored.

Input
- group: Column group in which the columns are located
- groupValues: TableValues in the group
"""
function setBoldValuesInGroup(group::ColumnGroup, groupValues::Vector{TableValue})  

    bestValues = Vector{TableValue}()
    
    for tableValue in groupValues
        if tableValue.isNumerical && !tableValue.ignoreBold
            isAmongTheBest = length(bestValues) == 0 ||
                (tableValue.value  >= bestValues[1].value && !group.isBestValueMinimal) ||
                (tableValue.value  <= bestValues[1].value && group.isBestValueMinimal)

            if isAmongTheBest
                isTheOnlyBest = length(bestValues) == 0 ||
                    (tableValue.value  > bestValues[1].value && !group.isBestValueMinimal) ||
                    (tableValue.value  < bestValues[1].value && group.isBestValueMinimal)
                if isTheOnlyBest
                    empty!(bestValues)
                end 
                push!(bestValues, tableValue) 
            end 
        end
    end
    
    for tableValue in bestValues
        tableValue.displayedValue = raw"""\mathbf{""" * tableValue.displayedValue * "}"
    end
end 

function createTableHeader(tableParam, rowVariables, columns, containColumnGroups)

    # Create the table header
    tableHeader = raw"""
    \begin{center}
    \resizebox{\textwidth}{!}{$\begin{array}{"""

    if tableParam.leftVline
        tableHeader *= "|"
    end 

    if length(rowVariables) != 0
        tableHeader *= "*{" * string(length(rowVariables)) * "}{r}"
    end 

    if tableParam.expandInstances
        tableHeader *= "r"
    end 

    if tableParam.vlineAfterRowParams
        tableHeader *= "|"
    end
    
    lastColumnHasVline = false

    for column in columns
        if typeof(column) == ColumnGroup
            for col in column.columns
                tableHeader *= "r"

                if col.vlineAfter || col == column.columns[length(column.columns)] && column.vlineAfter
                    tableHeader *= "|"
                    lastColumnHasVline = true
                else
                    lastColumnHasVline = false
                end
            end

            if !lastColumnHasVline && column.vlineAfter
                tableHeader *= "|"
                lastColumnHasVline = true
            end 
        else
            tableHeader *= "r"

            if column.vlineAfter
                tableHeader *= "|"
                lastColumnHasVline = true
            else
                lastColumnHasVline = false
            end
        end
    end

    if !lastColumnHasVline && tableParam.rightVline
        tableHeader *= "|"
    end

    # Add an empty last column to ease rows construction
    tableHeader *= "@{}r@{}}\n"
    tableHeader *= raw"""\hline"""

    csvCGHeader = ""
    csvSecondHeader = ""
    # For each row variable
    for rowVar in rowVariables

        csvCGHeader *= ", "
	csvSecondHeader *= rowVar.displayedName * ", "
        if containColumnGroups
            tableHeader *= raw"""\multirow{2}{*}{\textbf{""" * rowVar.displayedName * "}} & " 
        else
            tableHeader *= raw"""\textbf{""" * rowVar.displayedName * "} & " 
        end
    end

    if tableParam.expandInstances
        csvCGHeader *= ", "
	csvSecondHeader *= "Instance, "
        if containColumnGroups
            tableHeader *= raw"""\multirow{2}{*}{\textbf{Instance}} & """
        else 
            tableHeader *= raw"""\textbf{Instance} & """
        end 
    end 

    # For each result column
    for column in columns
        if typeof(column) == ColumnGroup

            csvCGHeader *= column.groupName * ", "^length(column.columns)
            for col in column.columns
                csvSecondHeader *= col.columnName * ", "
            end
	    
            tableHeader *= raw"""\multicolumn{""" * string(length(column.columns)) * "}{c"

            # If
            # - a line is specified after this group of columns; or if
            # - the last column of the group has a line after; or if
            # - this group is the last of the table and the table has a line on its right
            if column.vlineAfter || column.columns[end].vlineAfter || column == columns[end] && tableParam.rightVline
                tableHeader *= "|"
            end

            tableHeader *= raw"""}{\textbf{""" * column.groupName * "}} & "
        else
	    csvCGHeader *= ", "
	    csvSecondHeader *= column.columnName
            if containColumnGroups
                tableHeader *= raw"""\multirow{2}{*}{\textbf{\mbox{\textbf{""" * join(column.columnName) * "}}}} & "
            else
                tableHeader *= raw"""\textbf{\mbox{\textbf{""" * join(column.columnName) * "}}} & "
            end
        end
    end

    # If there are column groups, the table header contains a second row
    if containColumnGroups
        tableHeader *= raw"""\\\\"""
        tableHeader *= "\n"

        tableHeader *= "&"^length(rowVariables)

        if tableParam.expandInstances
            tableHeader *= "&"
        end
        
        for column in columns
            if typeof(column) == ColumnGroup
                for col in column.columns
                    tableHeader *= raw""" \mbox{\textbf{""" * col.columnName * "}} & "
                end
            else
                tableHeader *= "&"
            end
        end
    end

    tableHeader *= raw"""\\\hline""" * "\n\n"

    if containColumnGroups
        csvSecondHeader = csvCGHeader * "\n" * csvSecondHeader
    end
    return tableHeader, csvSecondHeader
end 

"""
Test if any resolution methods used to compute the value of a column has missing values for an instance.

Input
- column: the column 
- instanceResults: the result of the considered instance
"""
function hasMissingResults(column::Column, instanceResults::InstanceResults)

    hasMissingResults = false

    # For each resolution method used in the column
    for valueInfo in column.valInfos
        if haskey(instanceResults.methodResults, valueInfo.resolutionMethod)

            # If the instance has missing values for this method
            if !instanceResults.methodResults[valueInfo.resolutionMethod].hasAllResults
                hasMissingResults = true
            end 
        end 
    end

    return hasMissingResults
end 

"""
Add to a String which represents the current row of a table the value of a vector of TableValue.
If the table starts before this row, print the table header.
If the table ends after this row, print the table footer.

Input
- tableValues: the value to add to the row
- mustReprintHeader: true if the header must be printed before the row;
- outputstream: stream in which the row must be printed
- tableaHeader: header of the table
- latexRow: the string of the result row which already included the value dedicated to the row parameters
- rowCount: number of rows currently in the table
- tableHasMissingValues: true if the current table has missing values
- tableParam: parameters of the table
"""
function addResultsToRow(tableValues::Vector{TableValue}, mustReprintHeader::Bool, outputstream, csvOutputStream, tableHeader::String, latexRow::String, rowCount::Int, tableHasMissingValues::Bool, tableParam::TableParameters, containColumnGroups::Bool)

    generateCSVOutput = csvOutputStream != IOStream(string())

    if mustReprintHeader
        println(outputstream, tableHeader)
        mustReprintHeader = false
    end
    
    for tableValue in tableValues
        if generateCSVOutput
	    if tableValue.value != nothing
                print(csvOutputStream, tableValue.value)
	    end
	    print(csvOutputStream, ",")
	end
        latexRow *= tableValue.displayedValue * " & "
        if tableValue.isMissingMethodResults
            tableHasMissingValues = true
        end 
    end

    if generateCSVOutput
        println(csvOutputStream)
    end

    println(outputstream, latexRow * "\\\\\n\n")
    rowCount += 1
    latexRow = ""

    if rowCount >= tableParam.maxRowsInATable

        println(outputstream, getTableFooter(tableParam.caption, hasMissingValues=tableHasMissingValues))
        mustReprintHeader = true
        
        tableHasMissingValues = false
        rowCount = 1

        if containColumnGroups 
            rowCount = 2
        end
    end

    return rowCount, mustReprintHeader, tableHasMissingValues
end 

function displayStringDict(arg::Dict{String, Any})
    result = ""

    for (key, value) in arg
        result *= key * " = " * string(value) * "\n"
    end 
    return result
end 
