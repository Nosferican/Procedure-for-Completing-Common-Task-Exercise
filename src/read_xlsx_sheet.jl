"""
    read_xlsx_sheet(file::XLSXFile, sheetname::AbstractString)::DataFrame

Returns the data from the sheet for each series from 2010 forward.

Assumes:
- A1:A7 contains the metadata header
- Column names are given by the 8th row
    - A: Line
    - B: Description
    - C: PublishCd
    - D and on: Observation Period (e.g., 2010, 2010Q1, 2010M01)
- Data starts on the 9th row
Non-numeric values (e.g., ".....") are interpreted as 0.
"""
function read_xlsx_sheet(file::XLSXFile, sheetname::AbstractString)
    sheet = file[sheetname]
    # Only load headers
    colnames = vec(sheet[string("D8:", replace(string(sheet.dimension.stop), r"\d+" => 8))])
    # Label columns
    ln_desc_series = DataFrame(gettable(sheet, "A:C", first_row = 9, header = false, infer_eltypes = true,
                                        column_labels = [:Line, :Description, :PublishCd])...)
    # Based on the column names, find when 2010 data starts
    obs_start = findfirst(col -> startswith(col, "2010"), colnames)
    # Select 2010 data and forward
    datarange = string(encode_column_number(obs_start), # First column with 2010 data
                       "9:", # First row with data
                       encode_column_number(lastindex(colnames)), # Latest period
                       nrow(ln_desc_series) + 8, # Capture all variables based on the series
                       )
    # Only load the data portion
    data = DataFrame(getdata(sheet, datarange),
                     convert(Vector{String}, @view(colnames[obs_start:end])))
    data = hcat(ln_desc_series, data)
    # Exclude rows for ‘Addenda’ or ‘Per capita’ or any others that don’t have data
    subset!(data, :Line => ByRow(!ismissing))
    # Interpret non-numeric values (e.g., ".....") as 0.
    transform!(data,
               [:Line, :PublishCd] .=> disallowmissing,
               propertynames(data)[4:end] .=> ByRow(x -> isa(x, Integer) ? x : 0),
               renamecols = false)
end
