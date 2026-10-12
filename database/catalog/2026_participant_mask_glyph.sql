:setvar ApplyChanges "0"
:setvar Confirmation "PREVIEW"

USE [GreenCare_Production];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;

/*
  Replaces the small geometric circle U+25CB (○) with the CJK-sized
  ideographic zero U+3007 (〇) in the 13 approved individual labels.
  Preview is the default. Only dbo.Videos.Team may be changed.
*/
DECLARE @ApplyChanges bit = $(ApplyChanges);
DECLARE @Confirmation nvarchar(100) = N'$(Confirmation)';
DECLARE @RequiredConfirmation nvarchar(100) = N'APPLY 2026 PARTICIPANT MASK GLYPH';

IF DB_NAME() <> N'GreenCare_Production'
    THROW 51140, 'This script may run only in GreenCare_Production.', 1;

DECLARE @Labels table
(
    Id tinyint NOT NULL PRIMARY KEY,
    Number varchar(2) NOT NULL UNIQUE,
    CurrentLabel nvarchar(200) NOT NULL,
    NewLabel nvarchar(200) NOT NULL
);

INSERT @Labels (Id, Number, CurrentLabel, NewLabel)
VALUES
    (1,  '01', N'新竹市東區水源社區發展協會-黃○鳳',                   N'新竹市東區水源社區發展協會-黃〇鳳'),
    (2,  '02', N'臺中市神岡區溪洲社區發展協會-林○治',                 N'臺中市神岡區溪洲社區發展協會-林〇治'),
    (3,  '03', N'苗栗縣竹南鎮塭內社區發展協會-莊○雀',                 N'苗栗縣竹南鎮塭內社區發展協會-莊〇雀'),
    (4,  '04', N'苗栗縣後龍鎮埔頂社區發展協會-劉○妹',                 N'苗栗縣後龍鎮埔頂社區發展協會-劉〇妹'),
    (5,  '05', N'苗栗縣竹南鎮塭內社區發展協會-王○珠',                 N'苗栗縣竹南鎮塭內社區發展協會-王〇珠'),
    (6,  '06', N'社團法人南投縣埔里鎮枇杷社區發展協會-塗○英',         N'社團法人南投縣埔里鎮枇杷社區發展協會-塗〇英'),
    (7,  '07', N'南投縣埔里鎮一新社區發展協會-林○生',                 N'南投縣埔里鎮一新社區發展協會-林〇生'),
    (8,  '08', N'臺南市後壁區菁寮社區發展協會-廖○貞',                 N'臺南市後壁區菁寮社區發展協會-廖〇貞'),
    (9,  '09', N'屏東縣萬丹鄉社中社區發展協會-黃○愛',                 N'屏東縣萬丹鄉社中社區發展協會-黃〇愛'),
    (10, '10', N'社團法人中華民國慈惠善導書院文化教育研究協會-何○惠', N'社團法人中華民國慈惠善導書院文化教育研究協會-何〇惠'),
    (11, '11', N'屏東縣萬丹鄉社中社區發展協會-黃○',                   N'屏東縣萬丹鄉社中社區發展協會-黃〇'),
    (12, '12', N'高雄市旗山區糖廠社區發展協會-劉曾○容',               N'高雄市旗山區糖廠社區發展協會-劉曾〇容'),
    (13, '13', N'臺東縣池上鄉萬安社區發展協會-邱○妹',                 N'臺東縣池上鄉萬安社區發展協會-邱〇妹');

IF (SELECT COUNT(*) FROM @Labels) <> 13
    THROW 51141, 'Expected exactly 13 participant labels.', 1;

IF EXISTS
(
    SELECT 1
    FROM @Labels AS expected
    LEFT JOIN dbo.Videos AS video ON video.Id = expected.Id
    WHERE video.Id IS NULL
       OR video.Number <> expected.Number
       OR video.Category <> 'individual'
       OR video.SortOrder <> expected.Id
       OR video.IsActive <> 1
       OR video.Team NOT IN (expected.CurrentLabel, expected.NewLabel)
)
    THROW 51142, 'Database metadata or participant label differs from the approved source. Nothing was changed.', 1;

SELECT
    video.Number,
    video.Team AS CurrentLabel,
    expected.NewLabel,
    CASE WHEN video.Team = expected.NewLabel THEN N'ALREADY APPLIED' ELSE N'WILL UPDATE' END AS Action
FROM @Labels AS expected
INNER JOIN dbo.Videos AS video ON video.Id = expected.Id
ORDER BY video.Id;

IF @ApplyChanges = 0
BEGIN
    PRINT N'PREVIEW ONLY. Nothing was changed.';
    RETURN;
END;

IF @Confirmation <> @RequiredConfirmation
    THROW 51143, 'Confirmation is missing or incorrect. Nothing was changed.', 1;

DECLARE @ExpectedUpdates int =
(
    SELECT COUNT(*)
    FROM @Labels AS expected
    INNER JOIN dbo.Videos AS video ON video.Id = expected.Id
    WHERE video.Team = expected.CurrentLabel
);

BEGIN TRY
    BEGIN TRANSACTION;

    UPDATE video
    SET Team = expected.NewLabel
    FROM dbo.Videos AS video
    INNER JOIN @Labels AS expected ON expected.Id = video.Id
    WHERE video.Team = expected.CurrentLabel;

    IF @@ROWCOUNT <> @ExpectedUpdates
        THROW 51144, 'The updated row count differs from the validated preview; the transaction will be rolled back.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM @Labels AS expected
        INNER JOIN dbo.Videos AS video ON video.Id = expected.Id
        WHERE video.Team <> expected.NewLabel
    )
        THROW 51145, 'Post-update verification failed; the transaction will be rolled back.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT video.Number, video.Team AS AppliedLabel
FROM @Labels AS expected
INNER JOIN dbo.Videos AS video ON video.Id = expected.Id
ORDER BY video.Id;

PRINT CONCAT(N'Participant mask glyph update succeeded. Updated rows: ', @ExpectedUpdates, N'.');
GO
