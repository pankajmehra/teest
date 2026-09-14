using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Serilog;
using System.Data.SqlClient;    
using Anthem.Recon.Import;
using Anthem.Recon.Import.Interfaces;
using Anthem.Recon.Import.Services;
using Anthem.Recon.Import.Models;
using Microsoft.Data.SqlClient;
using System.Diagnostics.Eventing.Reader;
using Microsoft.AspNetCore.Mvc.Formatters;
using System.Diagnostics;

#region Configuration
string environmentName = string.Empty;
using IHost host = Host.CreateDefaultBuilder(args)
    .ConfigureServices((context, services) =>
    {
        var configurationRoot = context.Configuration;
        services.AddTransient<IConnectionService, ConnectionService>();
        services.AddTransient<IFileService, FileService>();
        services.AddTransient<IDatamportService, DataImportService>();
        //services.AddTransient<IStageToAnthemReconDetailService, StageToAnthemReconDetailService>();
        services.Configure<ApplicationSettings>(configurationRoot.GetSection(nameof(ApplicationSettings)));

        // Write the example settings to the console
        // Replace or remove
        //var options = configurationRoot.GetSection(nameof(ApplicationSettings)).Get<ApplicationSettings>();
        //var cs = configurationRoot.GetConnectionString("Default");
        //Console.WriteLine($"ConnectionStrings.Default={cs}");
        //Console.WriteLine($"ApplicationSettings.AppSetting1={options.AppSetting1}");
        //Console.WriteLine($"ApplicationSettings.AppSetting2={options.AppSetting2}");
    })
    .UseSerilog((context, configuration) => {
        configuration.ReadFrom.Configuration(context.Configuration);
    })
    .ConfigureAppConfiguration((context, configuration) =>
    {
        environmentName = (args.Length >= 1 && !string.IsNullOrWhiteSpace(args[0])) ? args[0] : "Production";

        configuration.AddJsonFile($"appsettings.json", optional: false, reloadOnChange: true);
        configuration.AddJsonFile($"appsettings.{environmentName}.json", optional: true);
    })
      .Build();

#endregion

#region Application Code

Log.Information($"****** Anthem.Recon.Import program start ****** Environment name {environmentName}");

int exitCode = 0;
try
{
    //  call to services, repositories, etc. here
    var fs = host.Services.GetService<IFileService>();
    var ds = host.Services.GetService<IDatamportService>();

    //Console.WriteLine($"ConnectionStrings.Default={cs}");
    //Console.WriteLine($"File list={fs.GetFileList()}");

    //fs.DisplayValues();
    AnthemReconFile reconFile = new AnthemReconFile();

    bool fileImported = false;
    int reconfile_id = 0;
   var fileList = fs.GetFileList();

    //fs.MoveFile($"{fs.InFileOriginalDirectory}{"WebTPARecon_Daily_08202025.csv"}", $"{fs.InFileConvertedDirectory}{"WebTPARecon_Daily_08202025.csv"}");
    if (fileList.Count() > 1)
    {
        string mssg = $"only 1 recon file is expected";
        Console.WriteLine(mssg);
        Log.Information(mssg);
    }

    if (fileList != null)
    {
        using (SqlConnection conn = new SqlConnection(host.Services.GetService<IConnectionService>().GetDefaultConnectionString()))
        {
            conn.Open();

            foreach (var file in fileList)
            {
                string fileNamePath = string.Empty;
                if (fs.FileFound(file))
                {
                    fileNamePath = Path.GetFileName(file);

                    if (ds.checkFileName(fileNamePath))
                    {
                        // Write file name information to ReconFile table
                        reconfile_id = ds.AddToReconFile(conn, fs, fileNamePath);

                        if (reconfile_id > 0)
                        {
                            bool success = ds.AddToReconFileStage(conn, fs, fileNamePath, reconfile_id);
                            if (success)
                            {
                                ds.updateReconFile(conn, reconfile_id);
                                if (success)
                                {
                                    fs.MoveFile($"{fs.InFileOriginalDirectory}{fileNamePath}", $"{fs.InFileConvertedDirectory}{fileNamePath}");
                                    string mssg = $"File {fileNamePath} successfully imported and moved to processed folder";
                                    Console.WriteLine(mssg);
                                    Log.Information(mssg);

                                    if (ds.populateReconFile(conn,reconfile_id)) //load anthem_recon_detail table
                                    {
                                        fileImported  = true; 

                                        Log.Information(string.Format("File loaded into anthem_Recon_detail table {0}",fileNamePath));
                                    }
                                    else
                                    {
                                        Log.Error(string.Format("Error while loading into anthem_Recon_detail table {0}", fileNamePath));
                                    }
                                }
             
                            }
                            else
                            {
                                fs.MoveFile($"{fs.InFileOriginalDirectory}{fileNamePath}", $"{fs.ErrorFileOriginalDirectory}{fileNamePath}");
                                string mssg = $"Error importing file {fs.ErrorFileOriginalDirectory}{fileNamePath}";
                                Console.WriteLine(mssg);
                                Log.Error(mssg);

                            }
                        }
                        else
                        {
                            string mssg = $"Error inserting file name info into recon file table.";
                            Console.WriteLine(mssg);
                            Log.Error(mssg);

                        }
                        
                    }
                    else
                    {
                        fs.MoveFile($"{fs.InFileOriginalDirectory}{fileNamePath}", $"{fs.ErrorFileOriginalDirectory}{fileNamePath}");
                        string mssg = $"Error importing file {fs.ErrorFileOriginalDirectory}{fileNamePath}, Invalid File Name";
                        Console.WriteLine(mssg);
                        Log.Error(mssg);

                    }

                }

                if (fileImported)
                {
                    using (SqlConnection mcrDcProdConnection = new SqlConnection(host.Services.GetService<IConnectionService>().GetMcrDcProdConnectionString()))
                    {
                        mcrDcProdConnection.Open();
                        bool claimMatchingCompleted = false;
                        var sw = new Stopwatch();
                        sw.Start();

                        if (ds.PerformClaimMatching(mcrDcProdConnection, fileNamePath))
                        {
                            claimMatchingCompleted = true;
                            Log.Information(string.Format("Claim Matching is completed for {0}", fileNamePath));
                        }
                        else
                        {
                            Log.Information(string.Format("Claim Matching failed for {0}", fileNamePath));
                        }
                        sw.Stop();
                        Log.Information($"Claim Matching Elapsed time {sw.Elapsed}");
                        sw.Reset();
                        sw.Start();
                        if (claimMatchingCompleted)
                        {
                            if (ds.PerformFinancialCompare(mcrDcProdConnection, fileNamePath))
                            {
                                claimMatchingCompleted = true;
                                Log.Information(string.Format("PerformFinancialCompare is completed for {0}", fileNamePath));
                            }
                            else
                            {
                                Log.Information(string.Format("PerformFinancialCompare failed for {0}", fileNamePath));
                            }
                            sw.Stop ();
                            Log.Information($"FinancialCompare Elapsed time {sw.Elapsed}");

                        }
                    }
                }
            }

            
        }
    }

   
}

catch (Exception ex)
{
    exitCode = 1;
    Log.Error(ex.ToString());
    Console.Error.WriteLine(ex.ToString()); 
    Environment.ExitCode = exitCode ;
    return;

}
finally
{
    if (exitCode == 0)
    {
        Log.Information("****** Anthem.Recon.Import program complete ******");
    }
    else
    {
        Log.Information("****** Anthem.Recon.Import program failed with errors ******");
    }
    Log.CloseAndFlush();
}

//await host.RunAsync();

#endregion


using Anthem.Recon.Import.Interfaces;
using Microsoft.Extensions.Options;
using Microsoft.Extensions.Logging;
using Microsoft.Data.SqlClient;
using Anthem.Recon.Import.Models;
using CsvHelper.Configuration;
using CsvHelper;
using Serilog;

using System.Data;

using System.ComponentModel;
using CsvHelper.Configuration.Attributes;
using System.Globalization;
using System.Reflection.PortableExecutable;
using System.Security.Principal;
using System.Transactions;
using System.Collections.Generic;
using System.Reflection;

namespace Anthem.Recon.Import.Services
{
    public class DataImportService : IDatamportService
    {
        #region Private Fields

        private readonly ApplicationSettings _options;
        private readonly ILogger<DataImportService> _logger;
        static StreamReader reader;
        static CsvHelper.CsvReader csv;
        List<AnthemReconFileStage> reconfiledata = new List<AnthemReconFileStage>();
        AnthemReconFile reconFile = new AnthemReconFile();
        public int _imported_count = 0;
        public int _load_rows = 0;
        SqlParameter _par;

        #endregion

        #region Properties

        public string AnthemReconFileTable
        { get { return _options.AnthemReconFileTable; } }

        public string AnthemReconFileStagingTable
        { get { return _options.AnthemReconFileStagingTable; } }

        public string AnthemReconFileNameFormat
        { get { return _options.FileNameFormat; } }

        //public int imported_count
        //{
        //    get { return _imported_count; }              
        //}

        //public int load_rows
        //{
        //    get { return _load_rows; }

        //}

        //int IDatamportService.load_count { get => throw new NotImplementedException(); set => throw new NotImplementedException(); }
        //int IDatamportService.imported_count { get => throw new NotImplementedException(); set => throw new NotImplementedException(); }

        #endregion

        #region Constructors

        public DataImportService(IOptions<ApplicationSettings> options, ILogger<DataImportService> logger)
        {
            _options = options.Value;
            _logger = logger;

        }

        #endregion

        #region Implementation Methods


        /// <summary>
        /// Display the app setting values
        /// </summary>
        //public void DisplayValues()
        //{
        //    _logger.LogInformation("Writing application settings...");

        //}
        public bool checkFileName(string fileNamePath)
        {
            bool valid = true;
            string fnameformat = AnthemReconFileNameFormat.ToLower();
            try
            {
                if (!fileNamePath.ToLower().Contains(fnameformat))
                {
                    valid = false;
                }
            } catch (Exception ex)
            {
                valid = false;
            }
            return valid;
        }

        public int AddToReconFile(SqlConnection con, IFileService fileService, string fileNamePath)
        {
            int reconfile_id = 0;
            try
            {
                using (SqlCommand cmd = new SqlCommand("dbo.anthem_recon_file_insert", con))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    _par = cmd.Parameters.Add("@file_name", SqlDbType.VarChar, 100);
                    _par.Direction = ParameterDirection.Input;
                    _par.Value = fileNamePath;
                    _par = cmd.Parameters.Add("@file_type", SqlDbType.VarChar, 50);
                    _par.Direction = ParameterDirection.Input;
                    _par.Value = "Anthem Recon File Log";
                    _par = cmd.Parameters.Add("@load_rows", SqlDbType.Int);
                    _par.Direction = ParameterDirection.Input;
                    _par.Value = 0;
                    _par = cmd.Parameters.Add("@created_user", SqlDbType.VarChar, 500);
                    _par.Direction = ParameterDirection.Input;
                    _par.Value = WindowsIdentity.GetCurrent().Name; //Environment.UserName;
                    _par = cmd.Parameters.Add("@anthem_recon_file_id", SqlDbType.Int);
                    _par.Direction = ParameterDirection.Output;
                    cmd.ExecuteNonQuery();
                    reconfile_id = Convert.ToInt32(cmd.Parameters["@anthem_recon_file_id"].Value);
                    cmd.Parameters.Clear();
                    return reconfile_id;
                }
            }
            catch (SqlException sqlEx)
            {
                Console.WriteLine(sqlEx);
                Log.Error(sqlEx.ToString());
                return reconfile_id = -1;
            }
        }

        public bool AddToReconFileStage(SqlConnection con, IFileService fileService, string fileNamePath, int reconFile_id)
        {
            bool returnVal = true;

            try
            {
                var config = new CsvConfiguration(CultureInfo.InvariantCulture)
                {
                    MissingFieldFound = null,
                    HasHeaderRecord = true,
                    TrimOptions = TrimOptions.Trim,
                    IgnoreBlankLines = true,
                    Delimiter = ",",
                    PrepareHeaderForMatch =
                    args => {
                        var h = args.Header.Replace("-", "_").Trim();
                        if (h == "835_DATE")
                            return "DATE_835";
                        return h;
                    }
                };


                reader = new StreamReader(File.OpenRead($"{fileService.InFileOriginalDirectory}{fileNamePath}"));
                csv = new CsvHelper.CsvReader(reader, config);

                var stripSpaces = new DecimalSpaceCleanupConverter();
                //Below will strip the spaces if there are spaces between the decimal number for e.g. '-    1.69'
                csv.Context.TypeConverterCache.AddConverter<decimal>(stripSpaces);
                csv.Context.TypeConverterCache.AddConverter<decimal?>(stripSpaces);


                //  csv.Configuration.PrepareHeaderForMatch = args => args.Header.Replace("-", "_");


                var csvRecords = csv.GetRecords<AnthemReconFileStage>().ToList();
                _load_rows = csvRecords.Count();
                reader.Close();

                //List<AnthemReconFileStage> csvRecords = csv.GetRecords<AnthemReconFileStage>().ToList();
                Console.WriteLine(csvRecords.Count());

                //DataTable dataTable = ToDataTable(csvRecords);
                DataTable dataTable = ToDataTable(csvRecords, fileNamePath, reconFile_id);


                //Bulk Insert dataTable into database
                using (var sqlBulkCopy = new SqlBulkCopy(con))
                {
                    //sqlBulkCopy.DestinationTableName = _options.AnthemReconFileStagingTable;
                    sqlBulkCopy.DestinationTableName = "dbo.anthem_recon_file_stage";
                    if (dataTable.Columns.Contains("DCN"))
                        sqlBulkCopy.ColumnMappings.Add("DCN", "DCN");
                    if (dataTable.Columns.Contains("MEMB_ID"))
                        sqlBulkCopy.ColumnMappings.Add("MEMB_ID", "MEMB_ID");
                    if (dataTable.Columns.Contains("CLM_TYP"))
                        sqlBulkCopy.ColumnMappings.Add("CLM_TYP", "CLM_TYP");
                    if (dataTable.Columns.Contains("PAT_LAST_NME"))
                        sqlBulkCopy.ColumnMappings.Add("PAT_LAST_NME", "PAT_LAST_NME");
                    if (dataTable.Columns.Contains("PAT_FRST_NME"))
                        sqlBulkCopy.ColumnMappings.Add("PAT_FRST_NME", "PAT_FRST_NME");
                    if (dataTable.Columns.Contains("PAT_DOB"))
                        sqlBulkCopy.ColumnMappings.Add("PAT_DOB", "PAT_DOB");
                    if (dataTable.Columns.Contains("CLT_CASE"))
                        sqlBulkCopy.ColumnMappings.Add("CLT_CASE", "CLT_CASE");
                    if (dataTable.Columns.Contains("CLT_GROUP"))
                        sqlBulkCopy.ColumnMappings.Add("CLT_GROUP", "CLT_GROUP");
                    if (dataTable.Columns.Contains("ITS_IND"))
                        sqlBulkCopy.ColumnMappings.Add("ITS_IND", "ITS_IND");
                    if (dataTable.Columns.Contains("PAY_ACT_CDE"))
                        sqlBulkCopy.ColumnMappings.Add("PAY_ACT_CDE", "PAY_ACT_CDE");
                    if (dataTable.Columns.Contains("CLM_ALW_AMT"))
                        sqlBulkCopy.ColumnMappings.Add("CLM_ALW_AMT", "CLM_ALW_AMT");
                    if (dataTable.Columns.Contains("TOT_APPR_PAY"))
                        sqlBulkCopy.ColumnMappings.Add("TOT_APPR_PAY", "TOT_APPR_PAY");
                    if (dataTable.Columns.Contains("COPAY_AMT"))
                        sqlBulkCopy.ColumnMappings.Add("COPAY_AMT", "COPAY_AMT");
                    if (dataTable.Columns.Contains("DEDUCT_AMT"))
                        sqlBulkCopy.ColumnMappings.Add("DEDUCT_AMT", "DEDUCT_AMT");
                    if (dataTable.Columns.Contains("COINS_AMT"))
                        sqlBulkCopy.ColumnMappings.Add("COINS_AMT", "COINS_AMT");
                    if (dataTable.Columns.Contains("TOT_CHG_AMT"))
                        sqlBulkCopy.ColumnMappings.Add("TOT_CHG_AMT", "TOT_CHG_AMT");
                    if (dataTable.Columns.Contains("ITEM_CD"))
                        sqlBulkCopy.ColumnMappings.Add("ITEM_CD", "ITEM_CD");
                    if (dataTable.Columns.Contains("PRIOR_PAY"))
                        sqlBulkCopy.ColumnMappings.Add("PRIOR_PAY", "PRIOR_PAY");
                    if (dataTable.Columns.Contains("DEBIT_CREDIT"))
                        sqlBulkCopy.ColumnMappings.Add("DEBIT_CREDIT", "DEBIT_CREDIT");
                    if (dataTable.Columns.Contains("INELIG_AMT"))
                        sqlBulkCopy.ColumnMappings.Add("INELIG_AMT", "INELIG_AMT");
                    if (dataTable.Columns.Contains("SURG_CLM_IND"))
                        sqlBulkCopy.ColumnMappings.Add("SURG_CLM_IND", "SURG_CLM_IND");
                    if (dataTable.Columns.Contains("SRG_TOT_AMT"))
                        sqlBulkCopy.ColumnMappings.Add("SRG_TOT_AMT", "SRG_TOT_AMT");
                    if (dataTable.Columns.Contains("SRG_MEM_AMT"))
                        sqlBulkCopy.ColumnMappings.Add("SRG_MEM_AMT", "SRG_MEM_AMT");
                    if (dataTable.Columns.Contains("SRG_ATH_AMT"))
                        sqlBulkCopy.ColumnMappings.Add("SRG_ATH_AMT", "SRG_ATH_AMT");
                    if (dataTable.Columns.Contains("SUPP_DOL_AMT"))
                        sqlBulkCopy.ColumnMappings.Add("SUPP_DOL_AMT", "SUPP_DOL_AMT");
                    if (dataTable.Columns.Contains("PAYEE_CDE"))
                        sqlBulkCopy.ColumnMappings.Add("PAYEE_CDE", "PAYEE_CDE");
                    if (dataTable.Columns.Contains("ADJ_RSN_CDE"))
                        sqlBulkCopy.ColumnMappings.Add("ADJ_RSN_CDE", "ADJ_RSN_CDE");
                    if (dataTable.Columns.Contains("TPA_837_IND"))
                        sqlBulkCopy.ColumnMappings.Add("TPA_837_IND", "TPA_837_IND");
                    if (dataTable.Columns.Contains("FUND_INIT_IND"))
                        sqlBulkCopy.ColumnMappings.Add("FUND_INIT_IND", "FUND_INIT_IND");
                    if (dataTable.Columns.Contains("LST_PROC_DT"))
                        sqlBulkCopy.ColumnMappings.Add("LST_PROC_DT", "LST_PROC_DT");
                    if (dataTable.Columns.Contains("TPA_835_IND"))
                        sqlBulkCopy.ColumnMappings.Add("TPA_835_IND", "TPA_835_IND");
                    if (dataTable.Columns.Contains("DATE_835"))
                        sqlBulkCopy.ColumnMappings.Add("DATE_835", "DATE_835");
                    if (dataTable.Columns.Contains("ACC_PAY"))
                        sqlBulkCopy.ColumnMappings.Add("ACC_PAY", "ACC_PAY");
                    if (dataTable.Columns.Contains("CLM_SEQ"))
                        sqlBulkCopy.ColumnMappings.Add("CLM_SEQ", "CLM_SEQ");
                    if (dataTable.Columns.Contains("anthem_recon_file_id"))
                        sqlBulkCopy.ColumnMappings.Add("anthem_recon_file_id", "anthem_recon_file_id");
                    if (dataTable.Columns.Contains("file_name"))
                        sqlBulkCopy.ColumnMappings.Add("file_name", "file_name");
                    if (dataTable.Columns.Contains("created_user"))
                        sqlBulkCopy.ColumnMappings.Add("created_user", "created_user");
                    //_imported_count += sqlBulkCopy.RowsCopied;
                    sqlBulkCopy.WriteToServer(dataTable);

                    _imported_count = sqlBulkCopy.RowsCopied;
                }

            }
            catch (ApplicationException aex)
            {
                // e.ErrorFile(filePath);
                string msg = "Columns or sheets in Excel file are incorrectly named or missing";
                //e.ErrorEmail(con, fileService, fileNamePath, msg, "ERROR");
                Log.Error(aex.Message);
                return false;
            }
            catch (SqlException sqlex)
            {
                string mssg = "SQL Error in BulkInsert  (" + sqlex.Message + ") at line " + sqlex.LineNumber.ToString();
                //e.ErrorEmail(con, fileService, fileNamePath, mssg, "ERROR");
                Console.WriteLine(mssg);
                Log.Error(sqlex.Message);
                return false;
            }
            catch (Exception ex)
            {

                Console.WriteLine(ex);
                Log.Error(ex.ToString());
                return false;
            }
            return returnVal;
        }


        public static DataTable ToDataTable(List<AnthemReconFileStage> items, string fName, int rfile_id)
        {
            DataTable dataTable = new DataTable(typeof(AnthemReconFileStage).Name);

            // Get all properties of the class
            PropertyInfo[] properties = typeof(AnthemReconFileStage).GetProperties(BindingFlags.Public | BindingFlags.Instance);

            // Create columns in DataTable
            foreach (PropertyInfo property in properties)
            {
                dataTable.Columns.Add(property.Name.ToString().Trim(), Nullable.GetUnderlyingType(property.PropertyType) ?? property.PropertyType);

            }
            //dataTable.Columns.Add(new DataColumn("anthem_recon_file_id", typeof(string)));
            DataColumn recon_file_id = new DataColumn("anthem_recon_file_id", typeof(string));
            recon_file_id.DefaultValue = rfile_id;
            dataTable.Columns.Add(recon_file_id);
            DataColumn filename = new DataColumn("file_name", typeof(string));
            filename.DefaultValue = fName;
            dataTable.Columns.Add(filename);
            DataColumn created_user = new DataColumn("created_user", typeof(string));
            created_user.DefaultValue = WindowsIdentity.GetCurrent().Name;
            dataTable.Columns.Add(created_user);

            // Add rows to DataTable
            foreach (AnthemReconFileStage item in items)
            {
                DataRow row = dataTable.NewRow();
                foreach (PropertyInfo property in properties)
                {
                    row[property.Name] = property.GetValue(item) ?? DBNull.Value;

                }
                dataTable.Rows.Add(row);

            }

            return dataTable;
        }

        public bool updateReconFile(SqlConnection con, int reconFile_id)
        {
            bool success = true;
            int returnval = 0;

            try
            {
                using (SqlCommand cmd = new SqlCommand("dbo.anthem_recon_file_update", con))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    _par = cmd.Parameters.Add("@reconFile_id", SqlDbType.Int);
                    _par.Direction = ParameterDirection.Input;
                    _par.Value = reconFile_id;
                    _par = cmd.Parameters.Add("@load_rows", SqlDbType.Int);
                    _par.Direction = ParameterDirection.Input;
                    _par.Value = _load_rows;
                    _par = cmd.Parameters.Add("@imported_count", SqlDbType.Int);
                    _par.Direction = ParameterDirection.Input;
                    _par.Value = _imported_count;
                    int result = Convert.ToInt32(cmd.ExecuteNonQuery());
                    if (result > 0)
                    {
                        success = true;
                    }
                    cmd.Parameters.Clear();
                }
            }
            catch (SqlException sqlEx)
            {
                Console.WriteLine(sqlEx);
                Log.Error(sqlEx.ToString());
                success = false;
            }
            return success;
        }



        public bool populateReconFile(SqlConnection con,int reconFile_id)
        {
            bool success = true;

            try
            {
                using (SqlCommand cmd = new SqlCommand("dbo.anthem_recon_file_detail_insert", con))
                {
                    _par = cmd.Parameters.Add("@reconFile_id", SqlDbType.Int);
                    _par.Direction = ParameterDirection.Input;
                    _par.Value = reconFile_id;
                    cmd.CommandType = CommandType.StoredProcedure;
                    int result = Convert.ToInt32(cmd.ExecuteNonQuery());
                    if (result > 0)
                    {
                        success = true;
                    }
                    cmd.Parameters.Clear();
                }
            }
            catch (SqlException sqlEx)
            {
                Console.WriteLine(sqlEx);
                Log.Error(sqlEx.ToString());
                success = false;
            }
            return success;
        }


        public bool PerformClaimMatching(SqlConnection con, string fileNamePath)
        {
            bool success = true;

            try
            {
                using (SqlCommand cmd = new SqlCommand("dbo.anthem_recon_claim_match", con))
                {
                    _par = cmd.Parameters.Add("@filename", SqlDbType.VarChar, 250);
                    _par.Direction = ParameterDirection.Input;
                    _par.Value = fileNamePath;
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.CommandTimeout = 0;
                    int result = Convert.ToInt32(cmd.ExecuteNonQuery());
                    if (result > 0)
                    {
                        success = true;
                    }
                    cmd.Parameters.Clear();
                }
            }
            catch (SqlException sqlEx)
            {
                Console.WriteLine(sqlEx);
                Log.Error(sqlEx.ToString());
                success = false;
                throw;
            }
            return success;
        }

        public bool PerformFinancialCompare(SqlConnection con, string fileNamePath)
        {
            bool success = true;

            try
            {
                using (SqlCommand cmd = new SqlCommand("dbo.anthem_recon_financial_compare", con))
                {
                    _par = cmd.Parameters.Add("@ClaimId", SqlDbType.Int);
                    _par.Direction = ParameterDirection.Input;
                    _par.Value = null;
                    _par = cmd.Parameters.Add("@filename", SqlDbType.VarChar, 250);
                    _par.Direction = ParameterDirection.Input;
                    _par.Value = fileNamePath;
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.CommandTimeout = 0;
                    int result = Convert.ToInt32(cmd.ExecuteNonQuery());
                    if (result > 0)
                    {
                        success = true;
                    }
                    cmd.Parameters.Clear();
                }
            }
            catch (SqlException sqlEx)
            {
                Console.WriteLine(sqlEx);
                Log.Error(sqlEx.ToString());
                success = false;
                throw;
            }
            return success;
        }
        #endregion


    }
}
