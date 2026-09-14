USE [Edee]
GO

/*
    BCBSM Weekly Recon Import - Initial Database Objects

    Flow:
      1. dbo.BCBSM_Recon_File_Insert
      2. dbo.BCBSM_Recon_Stage_Clear
      3. Application parses the 292-character fixed-width record and uses SqlBulkCopy
         to load dbo.BCBSM_Recon_Stage
      4. dbo.BCBSM_Recon_File_Update
      5. dbo.BCBSM_Recon_Detail_Insert

    Layout assumptions:
      - Stage preserves raw fixed-width values as varchar.
      - Detail converts documented dates using YYYYMMDD (style 112).
      - Amounts are converted directly from the supplied numeric character value to MONEY,
        matching the existing Anthem pattern. No implied-decimal scaling is applied here
        because the BCBSM layout does not document one. Confirm against a real weekly file.
      - Byte widths are treated as authoritative where the two Excel sheets disagree:
          Provider Sanction = 10 chars (217-226)
          Final Filler      = 36 chars (257-292)
          IDR Indicator     = 1 char  (256)
          Patient Name      = varchar(30)
*/

/*==========================================================================
  TABLE: dbo.BCBSM_Recon_File
==========================================================================*/
CREATE TABLE [dbo].[BCBSM_Recon_File]
(
    [bcbsm_recon_file_id] INT IDENTITY(1,1) NOT NULL,
    [file_name]           VARCHAR(250) NULL,
    [file_type]           VARCHAR(250) NULL,
    [load_rows]           INT NULL,
    [processed]           BIT NOT NULL CONSTRAINT [DF_BCBSM_Recon_File_processed] DEFAULT ((0)),
    [imported_count]      INT NULL,
    [created_date]        DATETIME NOT NULL CONSTRAINT [DF_BCBSM_Recon_File_created_date] DEFAULT (GETDATE()),
    [created_user_id]     INT NULL,
    [created_user]        VARCHAR(100) NULL,
    [modified_date]       DATETIME NOT NULL CONSTRAINT [DF_BCBSM_Recon_File_modified_date] DEFAULT (GETDATE()),
    [modified_user_id]    INT NULL,
    [deleted]             BIT NOT NULL CONSTRAINT [DF_BCBSM_Recon_File_deleted] DEFAULT ((0)),
    [rework]              BIT NOT NULL CONSTRAINT [DF_BCBSM_Recon_File_rework] DEFAULT ((0)),
    CONSTRAINT [PK_BCBSM_Recon_File] PRIMARY KEY CLUSTERED
    (
        [bcbsm_recon_file_id] ASC
    ) WITH
    (
        PAD_INDEX = OFF,
        STATISTICS_NORECOMPUTE = OFF,
        IGNORE_DUP_KEY = OFF,
        ALLOW_ROW_LOCKS = ON,
        ALLOW_PAGE_LOCKS = ON,
        OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF,
        DATA_COMPRESSION = PAGE
    ) ON [PRIMARY]
) ON [PRIMARY]
GO

/*==========================================================================
  TABLE: dbo.BCBSM_Recon_Stage
  Raw data from the 292-character fixed-width BCBSM weekly recon file.
==========================================================================*/
CREATE TABLE [dbo].[BCBSM_Recon_Stage]
(
    [bcbsm_recon_stage_id]                INT IDENTITY(1,1) NOT NULL,

    [activation_plan]                     VARCHAR(3) NULL,   -- 001-003
    [icn]                                 VARCHAR(14) NULL,  -- 004-017
    [subscriber_number]                   VARCHAR(13) NULL,  -- 018-030
    [nasco_charge_amount]                 VARCHAR(9) NULL,   -- 031-039
    [nasco_allowed_amount]                VARCHAR(9) NULL,   -- 040-048
    [nasco_paid_amount]                   VARCHAR(9) NULL,   -- 049-057
    [nasco_paid_date]                     VARCHAR(8) NULL,   -- 058-065 YYYYMMDD
    [bank_withdrawal_amount]              VARCHAR(9) NULL,   -- 066-074
    [claim_type]                          VARCHAR(2) NULL,   -- 075-076
    [patient_name]                        VARCHAR(30) NULL,  -- 077-106
    [patient_dob]                         VARCHAR(8) NULL,   -- 107-114 YYYYMMDD
    [patient_sex]                         VARCHAR(1) NULL,   -- 115
    [provider_number]                     VARCHAR(14) NULL,  -- 116-129
    [first_date_of_service]               VARCHAR(8) NULL,   -- 130-137 YYYYMMDD
    [fund_savings_amount]                 VARCHAR(9) NULL,   -- 138-146
    [group_number]                        VARCHAR(13) NULL,  -- 147-159
    [adjustment_type]                     VARCHAR(2) NULL,   -- 160-161
    [queried_indicator]                   VARCHAR(1) NULL,   -- 162
    [filler_1]                            VARCHAR(4) NULL,   -- 163-166
    [taft_hartley_indicator_1]            VARCHAR(1) NULL,   -- 167
    [taft_hartley_indicator_2]            VARCHAR(1) NULL,   -- 168
    [subscriber_plan]                     VARCHAR(3) NULL,   -- 169-171
    [surcharge_indicator]                 VARCHAR(1) NULL,   -- 172
    [surcharge_pct_reduction]             VARCHAR(5) NULL,   -- 173-177
    [surcharge_amount_reduction]          VARCHAR(7) NULL,   -- 178-184
    [pgip_withhold_amount]                VARCHAR(9) NULL,   -- 185-193
    [payee_code]                          VARCHAR(1) NULL,   -- 194
    [its_dcr_indicator]                   VARCHAR(1) NULL,   -- 195
    [adjustment_reason_code]              VARCHAR(3) NULL,   -- 196-198
    [nasco_savings_amount]                VARCHAR(9) NULL,   -- 199-207
    [q_savings_amount]                    VARCHAR(9) NULL,   -- 208-216
    [provider_sanction_amount]            VARCHAR(10) NULL,  -- 217-226 (10 bytes)
    [private_room_differential_code]      VARCHAR(1) NULL,   -- 227
    [nasco_groupset]                      VARCHAR(5) NULL,   -- 228-232
    [provider_tax_id]                     VARCHAR(9) NULL,   -- 233-241
    [fund_adjustment_indicator]           VARCHAR(1) NULL,   -- 242
    [rbe_amount]                          VARCHAR(9) NULL,   -- 243-251
    [capitation_indicator]                VARCHAR(1) NULL,   -- 252
    [federal_surprise_billing_indicator]  VARCHAR(1) NULL,   -- 253
    [its_surprise_billing_indicator]      VARCHAR(1) NULL,   -- 254
    [member_consent_indicator]            VARCHAR(1) NULL,   -- 255
    [idr_indicator]                       VARCHAR(1) NULL,   -- 256
    [filler_2]                            VARCHAR(36) NULL,  -- 257-292

    [bcbsm_recon_file_id]                 INT NOT NULL,
    [file_name]                           VARCHAR(256) NULL,
    [created_date]                        DATETIME NULL CONSTRAINT [DF_BCBSM_Recon_Stage_created_date] DEFAULT (GETDATE()),
    [created_user]                        VARCHAR(256) NULL,
    [deleted]                             BIT NULL CONSTRAINT [DF_BCBSM_Recon_Stage_deleted] DEFAULT ((0)),

    CONSTRAINT [PK_BCBSM_Recon_Stage] PRIMARY KEY CLUSTERED
    (
        [bcbsm_recon_stage_id] ASC
    ) WITH
    (
        PAD_INDEX = OFF,
        STATISTICS_NORECOMPUTE = OFF,
        IGNORE_DUP_KEY = OFF,
        ALLOW_ROW_LOCKS = ON,
        ALLOW_PAGE_LOCKS = ON,
        OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF,
        DATA_COMPRESSION = PAGE
    ) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_BCBSM_Recon_Stage_FileId]
ON [dbo].[BCBSM_Recon_Stage] ([bcbsm_recon_file_id])
WITH (DATA_COMPRESSION = PAGE)
GO

/*==========================================================================
  TABLE: dbo.BCBSM_Recon_Detail
==========================================================================*/
CREATE TABLE [dbo].[BCBSM_Recon_Detail]
(
    [bcbsm_recon_detail_id]               INT IDENTITY(1,1) NOT NULL,
    [bcbsm_recon_file_id]                 INT NOT NULL,

    [activation_plan]                     VARCHAR(3) NULL,
    [icn]                                 VARCHAR(14) NOT NULL,
    [subscriber_number]                   VARCHAR(13) NULL,
    [claim_type]                          VARCHAR(2) NOT NULL,

    -- Populated later by matching/reconciliation processing.
    [claim_id]                            INT NULL,
    [recon_tracking_status_id]            INT NULL,

    [nasco_charge_amount]                 MONEY NULL,
    [nasco_allowed_amount]                MONEY NULL,
    [nasco_paid_amount]                   MONEY NULL,
    [nasco_paid_date]                     DATETIME NULL,
    [bank_withdrawal_amount]              MONEY NULL,
    [patient_name]                        VARCHAR(30) NULL,
    [patient_dob]                         DATETIME NULL,
    [patient_sex]                         CHAR(1) NULL,
    [provider_number]                     VARCHAR(14) NULL,
    [first_date_of_service]               DATETIME NULL,
    [fund_savings_amount]                 MONEY NULL,
    [group_number]                        VARCHAR(13) NULL,
    [adjustment_type]                     VARCHAR(2) NULL,
    [queried_indicator]                   CHAR(1) NULL,
    [filler_1]                            VARCHAR(4) NULL,
    [taft_hartley_indicator_1]            CHAR(1) NULL,
    [taft_hartley_indicator_2]            CHAR(1) NULL,
    [subscriber_plan]                     VARCHAR(3) NULL,
    [surcharge_indicator]                 CHAR(1) NULL,

    -- Kept as the raw 5-character value because the layout does not document
    -- the implied decimal/scale of the percentage field.
    [surcharge_pct_reduction]             VARCHAR(5) NULL,

    [surcharge_amount_reduction]          MONEY NULL,
    [pgip_withhold_amount]                MONEY NULL,
    [payee_code]                          CHAR(1) NULL,
    [its_dcr_indicator]                   CHAR(1) NULL,
    [adjustment_reason_code]              VARCHAR(3) NULL,
    [nasco_savings_amount]                MONEY NULL,
    [q_savings_amount]                    MONEY NULL,
    [provider_sanction_amount]            MONEY NULL,
    [private_room_differential_code]      CHAR(1) NULL,
    [nasco_groupset]                      VARCHAR(5) NULL,
    [provider_tax_id]                     VARCHAR(9) NULL,
    [fund_adjustment_indicator]           CHAR(1) NULL,
    [rbe_amount]                          MONEY NULL,
    [capitation_indicator]                CHAR(1) NULL,
    [federal_surprise_billing_indicator]  CHAR(1) NULL,
    [its_surprise_billing_indicator]      CHAR(1) NULL,
    [member_consent_indicator]            CHAR(1) NULL,
    [idr_indicator]                       CHAR(1) NULL,
    [filler_2]                            VARCHAR(36) NULL,

    [filename]                            VARCHAR(256) NULL,
    [created_date]                        DATETIME NOT NULL CONSTRAINT [DF_BCBSM_Recon_Detail_created_date] DEFAULT (GETDATE()),
    [created_user_id]                     INT NOT NULL CONSTRAINT [DF_BCBSM_Recon_Detail_created_user_id] DEFAULT (SUSER_ID()),
    [modified_date]                       DATETIME NOT NULL CONSTRAINT [DF_BCBSM_Recon_Detail_modified_date] DEFAULT (GETDATE()),
    [modified_user_id]                    INT NOT NULL CONSTRAINT [DF_BCBSM_Recon_Detail_modified_user_id] DEFAULT (SUSER_ID()),
    [deleted]                             BIT NOT NULL CONSTRAINT [DF_BCBSM_Recon_Detail_deleted] DEFAULT ((0)),

    CONSTRAINT [PK_BCBSM_Recon_Detail] PRIMARY KEY CLUSTERED
    (
        [bcbsm_recon_detail_id] ASC
    ) WITH
    (
        PAD_INDEX = OFF,
        STATISTICS_NORECOMPUTE = OFF,
        IGNORE_DUP_KEY = OFF,
        ALLOW_ROW_LOCKS = ON,
        ALLOW_PAGE_LOCKS = ON,
        FILLFACTOR = 90,
        OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF
    ) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_BCBSM_Recon_Detail_FileId]
ON [dbo].[BCBSM_Recon_Detail] ([bcbsm_recon_file_id])
GO

CREATE NONCLUSTERED INDEX [IX_BCBSM_Recon_Detail_ICN]
ON [dbo].[BCBSM_Recon_Detail] ([icn])
GO

/*==========================================================================
  PROC: dbo.BCBSM_Recon_File_Insert
==========================================================================*/
CREATE OR ALTER PROCEDURE [dbo].[BCBSM_Recon_File_Insert]
    @bcbsm_recon_file_id INT OUTPUT,
    @file_name           VARCHAR(250),
    @file_type           VARCHAR(250),
    @load_rows           INT,
    @created_user        VARCHAR(250)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @sp_name        VARCHAR(128) = OBJECT_NAME(@@PROCID),
            @error_message  VARCHAR(MAX),
            @sec_user_id    INT,
            @sec_user_name  VARCHAR(128),
            @start          INT,
            @login_name     VARCHAR(128),
            @ProgramName    VARCHAR(100) = 'Finance Support';

    SELECT @sec_user_name = SUSER_SNAME();
    SELECT @start = CHARINDEX('\', @sec_user_name);
    SELECT @login_name = CASE
                            WHEN @start > 0 THEN SUBSTRING(@sec_user_name, @start + 1, LEN(@sec_user_name) - @start)
                            ELSE @sec_user_name
                         END;

    SELECT @sec_user_id = 0;
    SELECT @sec_user_id = sec_user_id
    FROM mcr_dc_prod.dbo.sec_user
    WHERE login_name = @login_name;

    BEGIN TRY
        INSERT INTO dbo.BCBSM_Recon_File
        (
            file_name,
            file_type,
            load_rows,
            processed,
            imported_count,
            created_user,
            created_user_id,
            modified_user_id
        )
        VALUES
        (
            @file_name,
            @file_type,
            @load_rows,
            0,
            0,
            @created_user,
            @sec_user_id,
            @sec_user_id
        );

        SET @bcbsm_recon_file_id = SCOPE_IDENTITY();
    END TRY
    BEGIN CATCH
        SET @error_message = 'A database error occurred:'
            + CHAR(13) + CHAR(10)
            + 'Procedure Name: ' + @sp_name
            + CHAR(13) + CHAR(10)
            + 'Error Description: ' + ERROR_MESSAGE()
            + CHAR(13) + CHAR(10)
            + 'User: ' + ISNULL(@login_name, 'Unknown');

        EXEC mcr_dc_prod.dbo.finance_email_notification
             @sec_user_id, @error_message, @ProgramName, @sp_name;

        THROW;
    END CATCH;
END
GO

/*==========================================================================
  PROC: dbo.BCBSM_Recon_Stage_Clear
  Required by the BCBSM story: clear prior staged file before new bulk copy.
==========================================================================*/
CREATE OR ALTER PROCEDURE [dbo].[BCBSM_Recon_Stage_Clear]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @sp_name        VARCHAR(128) = OBJECT_NAME(@@PROCID),
            @error_message  VARCHAR(MAX),
            @sec_user_id    INT,
            @sec_user_name  VARCHAR(128),
            @start          INT,
            @login_name     VARCHAR(128),
            @ProgramName    VARCHAR(100) = 'Finance Support';

    SELECT @sec_user_name = SUSER_SNAME();
    SELECT @start = CHARINDEX('\', @sec_user_name);
    SELECT @login_name = CASE
                            WHEN @start > 0 THEN SUBSTRING(@sec_user_name, @start + 1, LEN(@sec_user_name) - @start)
                            ELSE @sec_user_name
                         END;

    SELECT @sec_user_id = 0;
    SELECT @sec_user_id = sec_user_id
    FROM mcr_dc_prod.dbo.sec_user
    WHERE login_name = @login_name;

    BEGIN TRY
        TRUNCATE TABLE dbo.BCBSM_Recon_Stage;
    END TRY
    BEGIN CATCH
        SET @error_message = 'A database error occurred:'
            + CHAR(13) + CHAR(10)
            + 'Procedure Name: ' + @sp_name
            + CHAR(13) + CHAR(10)
            + 'Error Description: ' + ERROR_MESSAGE()
            + CHAR(13) + CHAR(10)
            + 'User: ' + ISNULL(@login_name, 'Unknown');

        EXEC mcr_dc_prod.dbo.finance_email_notification
             @sec_user_id, @error_message, @ProgramName, @sp_name;

        THROW;
    END CATCH;
END
GO

/*==========================================================================
  PROC: dbo.BCBSM_Recon_File_Update
  Called after the application finishes SqlBulkCopy into stage.
==========================================================================*/
CREATE OR ALTER PROCEDURE [dbo].[BCBSM_Recon_File_Update]
    @reconFile_id   INT,
    @load_rows      INT,
    @imported_count INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @sp_name        VARCHAR(128) = OBJECT_NAME(@@PROCID),
            @error_message  VARCHAR(MAX),
            @sec_user_id    INT,
            @sec_user_name  VARCHAR(128),
            @start          INT,
            @login_name     VARCHAR(128),
            @ProgramName    VARCHAR(100) = 'Finance Support';

    SELECT @sec_user_name = SUSER_SNAME();
    SELECT @start = CHARINDEX('\', @sec_user_name);
    SELECT @login_name = CASE
                            WHEN @start > 0 THEN SUBSTRING(@sec_user_name, @start + 1, LEN(@sec_user_name) - @start)
                            ELSE @sec_user_name
                         END;

    SELECT @sec_user_id = 0;
    SELECT @sec_user_id = sec_user_id
    FROM mcr_dc_prod.dbo.sec_user
    WHERE login_name = @login_name;

    BEGIN TRY
        UPDATE dbo.BCBSM_Recon_File
        SET load_rows       = @load_rows,
            imported_count  = @imported_count,
            modified_date   = GETDATE(),
            modified_user_id = @sec_user_id
        WHERE bcbsm_recon_file_id = @reconFile_id;

        IF @@ROWCOUNT = 0
            THROW 50001, 'BCBSM recon file record was not found.', 1;
    END TRY
    BEGIN CATCH
        SET @error_message = 'A database error occurred:'
            + CHAR(13) + CHAR(10)
            + 'Procedure Name: ' + @sp_name
            + CHAR(13) + CHAR(10)
            + 'Error Description: ' + ERROR_MESSAGE()
            + CHAR(13) + CHAR(10)
            + 'User: ' + ISNULL(@login_name, 'Unknown');

        EXEC mcr_dc_prod.dbo.finance_email_notification
             @sec_user_id, @error_message, @ProgramName, @sp_name;

        THROW;
    END CATCH;
END
GO

/*==========================================================================
  PROC: dbo.BCBSM_Recon_Detail_Insert
  Moves the staged rows for one weekly file into the typed detail table.
==========================================================================*/
CREATE OR ALTER PROCEDURE [dbo].[BCBSM_Recon_Detail_Insert]
    @reconFile_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @sp_name        VARCHAR(128) = OBJECT_NAME(@@PROCID),
            @error_message  VARCHAR(MAX),
            @sec_user_id    INT,
            @sec_user_name  VARCHAR(128),
            @start          INT,
            @login_name     VARCHAR(128),
            @ProgramName    VARCHAR(100) = 'Finance Support';

    SELECT @sec_user_name = SUSER_SNAME();
    SELECT @start = CHARINDEX('\', @sec_user_name);
    SELECT @login_name = CASE
                            WHEN @start > 0 THEN SUBSTRING(@sec_user_name, @start + 1, LEN(@sec_user_name) - @start)
                            ELSE @sec_user_name
                         END;

    SELECT @sec_user_id = 0;
    SELECT @sec_user_id = sec_user_id
    FROM mcr_dc_prod.dbo.sec_user
    WHERE login_name = @login_name;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.BCBSM_Recon_Detail
        (
            bcbsm_recon_file_id,
            activation_plan,
            icn,
            subscriber_number,
            claim_type,
            nasco_charge_amount,
            nasco_allowed_amount,
            nasco_paid_amount,
            nasco_paid_date,
            bank_withdrawal_amount,
            patient_name,
            patient_dob,
            patient_sex,
            provider_number,
            first_date_of_service,
            fund_savings_amount,
            group_number,
            adjustment_type,
            queried_indicator,
            filler_1,
            taft_hartley_indicator_1,
            taft_hartley_indicator_2,
            subscriber_plan,
            surcharge_indicator,
            surcharge_pct_reduction,
            surcharge_amount_reduction,
            pgip_withhold_amount,
            payee_code,
            its_dcr_indicator,
            adjustment_reason_code,
            nasco_savings_amount,
            q_savings_amount,
            provider_sanction_amount,
            private_room_differential_code,
            nasco_groupset,
            provider_tax_id,
            fund_adjustment_indicator,
            rbe_amount,
            capitation_indicator,
            federal_surprise_billing_indicator,
            its_surprise_billing_indicator,
            member_consent_indicator,
            idr_indicator,
            filler_2,
            filename,
            created_user_id,
            modified_user_id
        )
        SELECT
            rfs.bcbsm_recon_file_id,
            NULLIF(LTRIM(RTRIM(rfs.activation_plan)), ''),
            NULLIF(LTRIM(RTRIM(rfs.icn)), ''),
            NULLIF(LTRIM(RTRIM(rfs.subscriber_number)), ''),
            NULLIF(LTRIM(RTRIM(rfs.claim_type)), ''),

            CONVERT(MONEY, NULLIF(LTRIM(RTRIM(rfs.nasco_charge_amount)), '')),
            CONVERT(MONEY, NULLIF(LTRIM(RTRIM(rfs.nasco_allowed_amount)), '')),
            CONVERT(MONEY, NULLIF(LTRIM(RTRIM(rfs.nasco_paid_amount)), '')),

            CASE
                WHEN NULLIF(LTRIM(RTRIM(rfs.nasco_paid_date)), '') IS NULL
                     OR LTRIM(RTRIM(rfs.nasco_paid_date)) = '00000000'
                    THEN NULL
                ELSE CONVERT(DATETIME, LTRIM(RTRIM(rfs.nasco_paid_date)), 112)
            END,

            CONVERT(MONEY, NULLIF(LTRIM(RTRIM(rfs.bank_withdrawal_amount)), '')),
            NULLIF(LTRIM(RTRIM(rfs.patient_name)), ''),

            CASE
                WHEN NULLIF(LTRIM(RTRIM(rfs.patient_dob)), '') IS NULL
                     OR LTRIM(RTRIM(rfs.patient_dob)) = '00000000'
                    THEN NULL
                ELSE CONVERT(DATETIME, LTRIM(RTRIM(rfs.patient_dob)), 112)
            END,

            NULLIF(LTRIM(RTRIM(rfs.patient_sex)), ''),
            NULLIF(LTRIM(RTRIM(rfs.provider_number)), ''),

            CASE
                WHEN NULLIF(LTRIM(RTRIM(rfs.first_date_of_service)), '') IS NULL
                     OR LTRIM(RTRIM(rfs.first_date_of_service)) = '00000000'
                    THEN NULL
                ELSE CONVERT(DATETIME, LTRIM(RTRIM(rfs.first_date_of_service)), 112)
            END,

            CONVERT(MONEY, NULLIF(LTRIM(RTRIM(rfs.fund_savings_amount)), '')),
            NULLIF(LTRIM(RTRIM(rfs.group_number)), ''),
            NULLIF(LTRIM(RTRIM(rfs.adjustment_type)), ''),
            NULLIF(LTRIM(RTRIM(rfs.queried_indicator)), ''),
            rfs.filler_1,
            NULLIF(LTRIM(RTRIM(rfs.taft_hartley_indicator_1)), ''),
            NULLIF(LTRIM(RTRIM(rfs.taft_hartley_indicator_2)), ''),
            NULLIF(LTRIM(RTRIM(rfs.subscriber_plan)), ''),
            NULLIF(LTRIM(RTRIM(rfs.surcharge_indicator)), ''),
            NULLIF(LTRIM(RTRIM(rfs.surcharge_pct_reduction)), ''),
            CONVERT(MONEY, NULLIF(LTRIM(RTRIM(rfs.surcharge_amount_reduction)), '')),
            CONVERT(MONEY, NULLIF(LTRIM(RTRIM(rfs.pgip_withhold_amount)), '')),
            NULLIF(LTRIM(RTRIM(rfs.payee_code)), ''),
            NULLIF(LTRIM(RTRIM(rfs.its_dcr_indicator)), ''),
            NULLIF(LTRIM(RTRIM(rfs.adjustment_reason_code)), ''),
            CONVERT(MONEY, NULLIF(LTRIM(RTRIM(rfs.nasco_savings_amount)), '')),
            CONVERT(MONEY, NULLIF(LTRIM(RTRIM(rfs.q_savings_amount)), '')),
            CONVERT(MONEY, NULLIF(LTRIM(RTRIM(rfs.provider_sanction_amount)), '')),
            NULLIF(LTRIM(RTRIM(rfs.private_room_differential_code)), ''),
            NULLIF(LTRIM(RTRIM(rfs.nasco_groupset)), ''),
            NULLIF(LTRIM(RTRIM(rfs.provider_tax_id)), ''),
            NULLIF(LTRIM(RTRIM(rfs.fund_adjustment_indicator)), ''),
            CONVERT(MONEY, NULLIF(LTRIM(RTRIM(rfs.rbe_amount)), '')),
            NULLIF(LTRIM(RTRIM(rfs.capitation_indicator)), ''),
            NULLIF(LTRIM(RTRIM(rfs.federal_surprise_billing_indicator)), ''),
            NULLIF(LTRIM(RTRIM(rfs.its_surprise_billing_indicator)), ''),
            NULLIF(LTRIM(RTRIM(rfs.member_consent_indicator)), ''),
            NULLIF(LTRIM(RTRIM(rfs.idr_indicator)), ''),
            rfs.filler_2,
            rfs.file_name,
            @sec_user_id,
            @sec_user_id
        FROM dbo.BCBSM_Recon_Stage rfs
        WHERE rfs.bcbsm_recon_file_id = @reconFile_id
          AND ISNULL(rfs.deleted, 0) = 0;

        -- A file is marked processed only after the detail insert succeeds.
        UPDATE dbo.BCBSM_Recon_File
        SET processed        = 1,
            modified_date    = GETDATE(),
            modified_user_id = @sec_user_id
        WHERE bcbsm_recon_file_id = @reconFile_id;

        IF @@ROWCOUNT = 0
            THROW 50002, 'BCBSM recon file record was not found while marking the file processed.', 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        SET @error_message = 'A database error occurred:'
            + CHAR(13) + CHAR(10)
            + 'Procedure Name: ' + @sp_name
            + CHAR(13) + CHAR(10)
            + 'Error Description: ' + ERROR_MESSAGE()
            + CHAR(13) + CHAR(10)
            + 'User: ' + ISNULL(@login_name, 'Unknown');

        EXEC mcr_dc_prod.dbo.finance_email_notification
             @sec_user_id, @error_message, @ProgramName, @sp_name;

        THROW;
    END CATCH;
END
GO

/*==========================================================================
  Suggested smoke-test sequence (do not execute in production as-is)
==========================================================================

DECLARE @file_id INT;

EXEC dbo.BCBSM_Recon_File_Insert
     @bcbsm_recon_file_id = @file_id OUTPUT,
     @file_name            = 'BCBSM_RECON_TEST.txt',
     @file_type            = 'BCBSM RECON',
     @load_rows            = 0,
     @created_user         = 'Test User';

SELECT @file_id AS bcbsm_recon_file_id;

EXEC dbo.BCBSM_Recon_Stage_Clear;

-- Application parses fixed-width records and SqlBulkCopy loads stage here.

EXEC dbo.BCBSM_Recon_File_Update
     @reconFile_id   = @file_id,
     @load_rows      = 100,
     @imported_count = 100;

EXEC dbo.BCBSM_Recon_Detail_Insert
     @reconFile_id = @file_id;

SELECT * FROM dbo.BCBSM_Recon_File   WHERE bcbsm_recon_file_id = @file_id;
SELECT * FROM dbo.BCBSM_Recon_Stage  WHERE bcbsm_recon_file_id = @file_id;
SELECT * FROM dbo.BCBSM_Recon_Detail WHERE bcbsm_recon_file_id = @file_id;

==========================================================================*/
