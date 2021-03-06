# Format of a latex table file

To create a latex table within an experiment, you must describe it in a
JSON  file and  specify  the path  of this  file  in your  [experiment
file](./experimentation_format.md). The latex table file must contain an array of dictionaries. Each dictionary either corresponds to:
* the parameters of the table;
* a row parameter;
* a column parameter;
* a group of columns.

The syntax of each dictionary is presented in the following and illustrated on the following table:
<p align="center">
    <img src="images/knapsack_table_format.png" alt="Knapsack result table automatically generated by AutoExpe.jl" width="700"/>
</p>

As an example, the content of the JSON file used to describe the table above is available [here](../src/examples/knapsack/config/averageTable.json).

## Table parameters (optional)

This dictionary  describes the general properties of the table. Here is the dictionary of the table parameters of the table above: 

    {
	 "caption": "Knapsack results", 
	 "expandInstances": false, 
	 "leftVline": false, 
	 "rightVline": false, 
	 "vlineAfterRowParams": false
	 },

and its illustration:
<p align="center">
    <img src="images/knapsack_table_parameters.png" alt="Table parameters of the knapsack result table" width="700"/>
</p>

### Possible entries of the latex table dictionary

#### caption (mandatory)

Caption of the table:

Example:

    "caption": "My caption."

#### maxRowsInATable (optional)

Integer which specifies the maximal number of lines in a table. It can
be used to split the table in order to avoid tables which are taller than a page
(default value: `30`).

Example:

    "maxRowsInATable": 10

#### leftVline (optional)
Boolean which is true if a vertical  line is drawn on the left side of
the table and false otherwise (default value: `true`).

Example:

    "leftVline": false

#### rightVline (optional)
 Boolean which is true if a vertical line is drawn on the  right side of the table and false otherwise (default value: `true`).
 
#### vlineAfterRowParams (optional)
 Boolean which is true if a vertical line is drawn after each column which represent a row parameter (default value: `true`).

	
#### maxNonScientificValue (optional)
Integer equal to the greatest  numerical values displayed in the table
which  is  represented  without  the  scientific notation  (default:
`999999`, which means that 1000000 will be represented by 1E6).

Example:

    "maxNonScientificValue": 9999

#### expandInstances (optional)
Boolean  which is  true  if the  table displays  the  results of  each
instance (i.e., if for each combination of row parameters, there is one result line for each instance); false  if average  results over  all instances  are computed
(default: `false`).

#### hideInstancesExtension (optional)
When  `expandInstances`  is true,  each  row  corresponds to  results
obtained  for one  instance  and  the table  contains  a column  which
indicates the name of the instance associated to each row. The boolean
`hideInstancesExtension`  is true  if  the extension  of the  instance
files in this column is not displayed (default: `false`).

The value of `hideInstancesExtension` is ignored if `expandInstances` is false.


## Row parameter

A row parameter dictionary  describes an entry saved in the result files which value will vary across the rows of the table (e.g. : <img src="https://render.githubusercontent.com/render/math?math=m"> and <img src="https://render.githubusercontent.com/render/math?math=K"> in the table above).

Here is a representation of some entries of this dictionary on the knapsack table:
<p align="center">
    <img src="images/knapsack_row_parameters.png" alt="Table parameters of the knapsack result table" width="600"/>
</p>

### Possible entries of this dictionary

#### rowParameterName (mandatory)
Name of the parameter as it appears in the result files. 

Example:

    "rowParameterName": "knapsackCount"

#### displayedName (optional)
Name of the parameter as it will appear in the latex table. If this entry is not specified, the value of `"rowParameterName"` is used.

Note that to use latex mathematical expressions, you need put the expression between dollars and replace any backslash by two backslashes (e.g. : `$\\alpha$`).

Examples:

    "displayedName": "$m$"
    "displayedName": "$\\beta$"

#### indexes (optional)
If the  parameter is included  in an  array of dimension  D in  the result
files, the entry `indexes` must be an array of D integers which specifies at which index of the array is the value of the row parameter.

For example, let assume that each result file contains an array named `t` which contains four values and that we are interested in the third value of this array. We can define the row parameter as follows:

    {"rowParameterName": "t", "indexes": [3]}

#### hline (optional)
Boolean which is true if a horizontal line is drawn between rows which have different values of the parameter (default value `false`).


## Column parameter

This  dictionary describes  one result  column of  the table  (i.e., a
column which does  not correspond to row parameters  and which content
is obtained from the saved result files).  The
*entries* displayed in each row of a result column can either be obtained from:
* only one *value*  in the result files. In that  case, the entry is
  directly read from  the result files and written in  the latex table
  (e.g., if  the column displays  the resolution  time of a  method we
  directly read the corresponding entry in the result files);
* several *values*  in the result files. In that  case, all required
  values are read  from the result files and a  function is applied to
  them to  compute the  entry displayed  in the  column (e.g.,  if the
  columnd displays the  mean resolution time of two  different methods, `m1`
  and `m2`).

To identify a value in a result file, we must specify:
* the name of the value in the result files (e.g., `time`);
*  the resolution  method which  provided  this value  (e.g., `m1`  or
  `m2`).
  
These information can be specified in the entries `method` and `columnParameters`
presented below.

Here is the dictionaries associated to two columns of the knapsack table:

<p align="center">
    <img src="images/knapsack_column_parameters.png" alt="Table parameters of the knapsack result table" width="1000"/>
</p>


### Possible entries of the column parameter dictionary

#### method (optional)

Name of the resolution method used to obtain the values considered in this column. For example:

    "method": "myMethod"

The name of the resolution method must be the same than in the [experiment file](./experimentation_format.md).

When several  values are used  to compute  the entries of  the column,
these values may be associated  to different resolution methods (e.g.,
to compute the mean resolution time of methods
`m1` and `m2`). In that case, the resolution method of each value can be specified in the dictionary entry `"columnParameters"`.


#### columnParameters (mandatory)

Specifies the value(s)  from the saved files used to  obtain the value
in a column. A value can either be characterized by:

* a string (e.g., `"time"`); or
*  a dictionary  with  a  key `"name"`  and  a  key `"method"`  (e.g.,
`{"name": "time", "method": "m1"}`).

The entry `columnParameters` can only contain one value:

    "columnParameters": "time"
	
    "columnParameters": {"name": "time", "method": "m1"}
	
or an array of values:
	
    "columnParameters": [{"name": "time", "method": "m1"}, {"name": "time", "method": "m2"}]

If a value is inside an array in the result files, the dictionary must
specify at which index(es) (similarly to the row parameters presented above):

    "columnParameters": {"name": "times", "method": "m1", "indexes": 2}


#### vline (optional)

Boolean which is true if a vertical line is drawn after this column (default
value: `false`).

#### function (optional)

Function  used to  compute the  value in  the column.  Currently, only
`"gap"` and `"mean"` are available but more can be added on demand and
it should eventually be possible in the future for the users to define and specify them similarly to the
resolution methods.

#### digits (optional)

Number of significant figures displayed for non integer values (default: 2).

#### suffix (optional)

String added after each entry of the column (e.g.: `"min"`, `"%"`, `"g"`, ...).

#### prefix (optional)

String added before each entry of the column (e.g.: `"min"`, `"%"`, `"g"`, ...).

#### ignoreBold (optional)

 It is possible to
set the best value  of a group of columns in bold  (e.g., if the group
represents  the  resolution  time   of  several  methods).  The  entry
`ignoreBold` is true
if the value  in the column are ignored when  computing the best value
of  the group. Consequently, the values of the column will never be in bold.

This entry is ignored if the column is not in a group.

#### multiplier (optional)

All value in the column will be multiplied by this integer. Enables to change the scale of a column (e.g., "s", "ms", "ns", ...).

## Group of columns

It is possible  to group several columns under one  label (e.g., group
`Time` and `Objective` in the table above).

### Possible entries of a column group dictionary

#### columnGroupName (mandatory)

String which corresponds to the name of the group displayed in the latex table.

#### columns (mandatory)

Array  which  contains  the  columns  of  the  group.  Each  column  is
represented by a column parameter as presented above.

Example:

    "columns": [
	  {"columnParameters": "time", "method": "m1"},
	  {"columnParameters": "time", "method": "m2"}
	]

#### vlineAfter (optional)

True if a vertical line must  be drawn after the group (default value:
`false`).

#### highlightBestValue (optional)

True if  the best  value of  the groupe must  appear in  bold (default
value: `false`).

#### isBestValueMinimal (optional)

True if the best value of the group is the lowest one; false if it is the highest one (default value: `true`).





