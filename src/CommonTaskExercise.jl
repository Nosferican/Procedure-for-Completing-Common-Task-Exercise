module CommonTaskExercise

using XLSX: XLSX, XLSXFile, encode_column_number, gettable, getdata
using DataFrames: DataFrames, DataFrame, ByRow, transform!, nrow, subset!, disallowmissing
using LinearAlgebra: LinearAlgebra, AbstractMatrix, AbstractVector, Diagonal, diagm

foreach(include, ["read_xlsx_sheet.jl", "denton_interpolation.jl"])

export read_xlsx_sheet, denton_interpolation

end # module
