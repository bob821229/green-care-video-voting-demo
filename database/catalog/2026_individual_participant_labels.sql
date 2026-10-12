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
  Preview is the default and does not modify data.

  To apply after reviewing all 13 rows:
    SET @ApplyChanges = 1
    SET @Confirmation = N'APPLY 2026 INDIVIDUAL PARTICIPANT LABELS'

  Only dbo.Videos.Team for active individual works 01-13 is changed.
*/
DECLARE @ApplyChanges bit = 0;
DECLARE @Confirmation nvarchar(100) = N'';
DECLARE @RequiredConfirmation nvarchar(100) =
    N'APPLY 2026 INDIVIDUAL PARTICIPANT LABELS';

IF DB_NAME() <> N'GreenCare_Production'
    THROW 51120, 'This script may run only in GreenCare_Production.', 1;

DECLARE @Labels table
(
    Id tinyint NOT NULL PRIMARY KEY,
    Number varchar(2) NOT NULL UNIQUE,
    Title nvarchar(200) NOT NULL,
    CurrentTeam nvarchar(200) NOT NULL,
    NewTeam nvarchar(200) NOT NULL
);

INSERT @Labels (Id, Number, Title, CurrentTeam, NewTeam)
VALUES
    (1,  '01', N'看到你心花開',             N'新竹市東區水源社區發展協會',                     N'新竹市東區水源社區發展協會-黃○鳳'),
    (2,  '02', N'亭亭玉立的金治',            N'臺中市神岡區溪洲社區發展協會',                   N'臺中市神岡區溪洲社區發展協會-林○治'),
    (3,  '03', N'蝶舞綠照，樂活新生活',       N'苗栗縣竹南鎮塭內社區發展協會',                   N'苗栗縣竹南鎮塭內社區發展協會-莊○雀'),
    (4,  '04', N'小鐵馬的愛',                N'苗栗縣後龍鎮埔頂社區發展協會',                   N'苗栗縣後龍鎮埔頂社區發展協會-劉○妹'),
    (5,  '05', N'種下智慧，收獲幸福',         N'苗栗縣竹南鎮塭內社區發展協會',                   N'苗栗縣竹南鎮塭內社區發展協會-王○珠'),
    (6,  '06', N'認識枇杷社區不彎腰菜園',     N'社團法人南投縣埔里鎮枇杷社區發展協會',           N'社團法人南投縣埔里鎮枇杷社區發展協會-塗○英'),
    (7,  '07', N'爺的掃把',                  N'南投縣埔里鎮一新社區發展協會',                   N'南投縣埔里鎮一新社區發展協會-林○生'),
    (8,  '08', N'學習製作愛玉',              N'臺南市後壁區菁寮社區發展協會',                   N'臺南市後壁區菁寮社區發展協會-廖○貞'),
    (9,  '09', N'優游自在的沈愛姐',           N'屏東縣萬丹鄉社中社區發展協會',                   N'屏東縣萬丹鄉社中社區發展協會-黃○愛'),
    (10, '10', N'有伴的日子，真好',           N'社團法人中華民國慈惠善導書院文化教育研究協會',   N'社團法人中華民國慈惠善導書院文化教育研究協會-何○惠'),
    (11, '11', N'阿綢姐的月餅',              N'屏東縣萬丹鄉社中社區發展協會',                   N'屏東縣萬丹鄉社中社區發展協會-黃○'),
    (12, '12', N'菜園旁的幸福食堂',           N'高雄市旗山區糖廠社區發展協會',                   N'高雄市旗山區糖廠社區發展協會-劉曾○容'),
    (13, '13', N'自己種，安心又好吃',         N'台東縣池上鄉萬安社區發展協會',                   N'臺東縣池上鄉萬安社區發展協會-邱○妹');

IF (SELECT COUNT(*) FROM @Labels) <> 13
    THROW 51121, 'Expected exactly 13 individual participant labels.', 1;

IF EXISTS (SELECT 1 FROM @Labels WHERE LEN(NewTeam) > 200)
    THROW 51122, 'A participant label exceeds dbo.Videos.Team length.', 1;

IF EXISTS
(
    SELECT 1
    FROM @Labels AS expected
    LEFT JOIN dbo.Videos AS video ON video.Id = expected.Id
    WHERE video.Id IS NULL
       OR video.Number <> expected.Number
       OR video.Title <> expected.Title
       OR video.Team NOT IN (expected.CurrentTeam, expected.NewTeam)
       OR video.Category <> 'individual'
       OR video.SortOrder <> expected.Id
       OR video.IsActive <> 1
)
    THROW 51123, 'Database metadata differs from the approved source. Nothing was changed.', 1;

SELECT
    video.Id,
    video.Number,
    video.Title,
    expected.CurrentTeam AS CurrentLabel,
    expected.NewTeam AS NewLabel,
    CASE WHEN video.Team = expected.NewTeam THEN N'ALREADY APPLIED' ELSE N'WILL UPDATE' END AS Action
FROM @Labels AS expected
INNER JOIN dbo.Videos AS video ON video.Id = expected.Id
ORDER BY video.Id;

IF @ApplyChanges = 0
BEGIN
    PRINT N'PREVIEW ONLY. Nothing was changed.';
    RETURN;
END;

IF @Confirmation <> @RequiredConfirmation
    THROW 51124, 'Confirmation is missing or incorrect. Nothing was changed.', 1;

DECLARE @ExpectedUpdates int =
(
    SELECT COUNT(*)
    FROM @Labels AS expected
    INNER JOIN dbo.Videos AS video ON video.Id = expected.Id
    WHERE video.Team = expected.CurrentTeam
);

BEGIN TRY
    BEGIN TRANSACTION;

    UPDATE video
    SET Team = expected.NewTeam
    FROM dbo.Videos AS video
    INNER JOIN @Labels AS expected ON expected.Id = video.Id
    WHERE video.Team = expected.CurrentTeam;

    IF @@ROWCOUNT <> @ExpectedUpdates
        THROW 51125, 'The updated row count differs from the validated preview; the transaction will be rolled back.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM @Labels AS expected
        INNER JOIN dbo.Videos AS video ON video.Id = expected.Id
        WHERE video.Team <> expected.NewTeam
    )
        THROW 51126, 'Post-update verification failed; the transaction will be rolled back.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT
    video.Id,
    video.Number,
    video.Title,
    video.Team AS AppliedLabel
FROM @Labels AS expected
INNER JOIN dbo.Videos AS video ON video.Id = expected.Id
ORDER BY video.Id;

PRINT N'All 13 individual participant labels were updated successfully.';
GO
