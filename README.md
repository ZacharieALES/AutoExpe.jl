# AutoExpe
Automates repetitive taks in numerical experiments and the generation of result tables.

## Is it useful to me?
This package can be useful if you have:
* 1 problem (e.g., a [multiple knapsack problem](./docs/knapsack.md));
* at least 1 instance of this problem (e.g, [weight and values of the objects that can be added in the knapsacks](./src/examples/knapsack/data/knapsack1.json));
* at least 1 resolution method to solve this problem (e.g., [two knapsack methods](./docs/knapsack.md#heuristics));
* (optional) parameters of the problem (e.g., the number of knapsack <img src="https://render.githubusercontent.com/render/math?math=m"> and the size of the knapsacks <img src="https://render.githubusercontent.com/render/math?math=K">).

and if you want to automate:
* the resolution of each instance with each method for each value of the parameters;
* the creation of latex result tables such as the following one.


Here is an example of a table generated from the example located int [./src/examples/knapsack](./src/examples/knapsack):
<p align="center">
    <img src="docs/images/knapsack.png" alt="Knapsack result table automatically generated by AutoExpe.jl" width="400"/>
</p>

## What the package does and what it does not

To perform an experiment through this package, you must provide:
* the resolution methods ;
* the path of the instances;
* the different values of each parameters;
* (optional) the format of each result table.

The package does the rest which, among others, includes:
* apply all resolution methods on all instances for all combination of values of all parameters;
* manage the results: format, reading, writing;
* display logs: progress, errors, warnings, ...;
* interruption management: regular backups, resumption without unecessary recalculations;
* generation of latex result tables during and after the experiment.

## How to use the package

The user must create a [JSON](https://en.wikipedia.org/wiki/JSON) file which describes the experiment. The experiment can then be executed using the command:

    autoExpe("PATH/TO/MY_JSON_FILE.json")

If latex  tables must be generated,  a JSON file must  also be created
for each table. 

### Format of the experiment file
The user describes his experiment in a JSON file which only contains one dictionary. This dictionary must at least contain the two following keys:
* `"resolutionMethods"` which represents the resolution methods; and
* `"instancesPath"` which represents the instances.

Here is the content of the JSON file used to describe the experiment of the knapsack example:

    {
        "instancesPaths":"./data",
        "resolutionMethods": ["randomResolution", "ratioResolution"],
        "latexFormatPath":  ["./config/averageTable.json", "./config/expandedTable.json"],
        "latexOutputFile": "./results/result_tables.tex",
        "parametersToCombine": {"knapsacksCount": [1, 2, 3], "knapsacksSize": [10, 20, 30]}
    }

More details on the format are available [here](./docs/experimentation_format.md).

### Format of a latex table file 
The user describes a latex table in a JSON file which contains one array of dictionaries. 

Example of the structure of such a file:

    [{ TABLE_PARAMETERS },
     { ROW_PARAMETER },
     { COLUMN_PARAMETER }
    ]

Each dictionary either represents:
1. the table parameters (e.g., caption, vertical lines, ...); or
2. a row parameter: an entry saved in the result files which value will vary across the rows of the table (e.g. : <img src="https://render.githubusercontent.com/render/math?math=m"> and <img src="https://render.githubusercontent.com/render/math?math=K"> in the table above); 
3. a column parameter: describes the content of a column in the result table (e.g. : each of the last five columns in the previous table);
4. a group of columns: several columns in the table that will appear under a common label (e.g., the groups `Objective` and `Time` in the previous table).

The following quickly describes the format of each of these entries. More details are available [here](./docs/latex_table_format.md).

The content of the JSON file used to describe the table above is available [here](./src/examples/knapsack/config/averageTable.json).


#### Table parameters (optional)
This dictionary must contain an entry of key `"caption"` which represents the caption of the table. For example :

    {"caption": "Caption of my table"}


### Row parameters

This  dictionary  must  contain a  string  `"rowParameterName"`  which
corresponds to the name of the parameter as it appears in the result files.  For example:

    {"rowParameterName": "knapsacksSize"}

### Column parameters
This dictionary must contain the entries:
* `"columnParameters"` which specifies the result(s) from the
saved files used to obtain the value in the column;
* `"method"`  which specifies the resolution method
  used to obtain the result(s).
  
For example:

    {"columnParameters": "time", "method": "myMethod"}

If the  value in the column  is obtained from several  values from the
result files, `"columnParameters"` must be an array. For example, if we want to compute the mean value of two values `"v1"` and `"v2"`, we would use:

    {"columnParameters": ["v1", "v2"], "function": "mean", method": "myMethod"}
    
### Group of columns
This dictionary must contain the entries:
* `"columnGroupName"` which corresponds to the label displayed above the columns of the group;
* `"column"` which is an array of columns as defined in the previous section.

For example:

    {"columnGroupName": "Time", "column":
      {"columnParameters": "time", "method": "method1"},
      {"columnParameters": "time, "method": "method2"}
    }
    
## Resolution methods format
Currently  resolution methods  must be  implemented in  Julia but  the
package should eventually be able to execute any resolution method from any language. The julia resolution methods must:
* take  a single argument  of type `Dictionary{Key, Any}`.  This input
  will provide a value for each parameter and the path of the current instance (which enables the method to access the data related to the instance);
* return a `Dictionary{Key, Any}` which contains all the results to save.

See for example, methods `randomResolution` or `ratioResolution` from [knapsack.jl](./src/examples/knapsack/knapsack.jl).
