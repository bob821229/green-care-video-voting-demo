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
  Preview:
    sqlcmd -S labdb -E -b -f 65001 -i database/catalog/2026_youtube_id_refresh.sql

  Apply after reviewing the preview:
    sqlcmd -S labdb -E -b -f 65001 `
      -v ApplyChanges=1 Confirmation="APPLY 2026 YOUTUBE ID REFRESH" `
      -i database/catalog/2026_youtube_id_refresh.sql

  Only dbo.Videos.YouTubeId is changed. The script is idempotent and accepts
  either the validated previous ID or the approved new ID for every row.
*/
DECLARE @ApplyChanges bit = $(ApplyChanges);
DECLARE @Confirmation nvarchar(100) = N'$(Confirmation)';
DECLARE @RequiredConfirmation nvarchar(100) = N'APPLY 2026 YOUTUBE ID REFRESH';

IF DB_NAME() <> N'GreenCare_Production'
    THROW 51130, 'This script may run only in GreenCare_Production.', 1;

DECLARE @Videos table
(
    Id tinyint NOT NULL PRIMARY KEY,
    Number varchar(2) NOT NULL UNIQUE,
    Category varchar(20) NOT NULL,
    SortOrder int NOT NULL,
    Title nvarchar(200) NOT NULL,
    PreviousYouTubeId varchar(32) NOT NULL,
    NewYouTubeId varchar(32) NOT NULL
);

INSERT @Videos (Id, Number, Category, SortOrder, Title, PreviousYouTubeId, NewYouTubeId)
VALUES
    (1,  '01', 'individual', 1,  N'看到你心花開',                         '8XyWphPLAxg', '8XyWphPLAxg'),
    (2,  '02', 'individual', 2,  N'亭亭玉立的金治',                        'UwKr9613to0', '09NevusclHU'),
    (3,  '03', 'individual', 3,  N'蝶舞綠照，樂活新生活',                   'KLGkxFwtlw4', 'KLGkxFwtlw4'),
    (4,  '04', 'individual', 4,  N'小鐵馬的愛',                            'Qv0BV1M4Iog', 'q3xQdksOdqM'),
    (5,  '05', 'individual', 5,  N'種下智慧，收獲幸福',                    'V-l94W68bzw', 'V-l94W68bzw'),
    (6,  '06', 'individual', 6,  N'認識枇杷社區不彎腰菜園',                '_Twv1vyVCRw', '_Twv1vyVCRw'),
    (7,  '07', 'individual', 7,  N'爺的掃把',                              'jBmbSjhnEkM', 'jBmbSjhnEkM'),
    (8,  '08', 'individual', 8,  N'學習製作愛玉',                          'Mv3c-2vxwik', 'yqUDv_KS9yU'),
    (9,  '09', 'individual', 9,  N'優游自在的沈愛姐',                      'M0umYSS_n4M', 'hRB_S0_HzFw'),
    (10, '10', 'individual', 10, N'有伴的日子，真好',                      'L3xhH2Q93dY', 'WTGS7q90ZSw'),
    (11, '11', 'individual', 11, N'阿綢姐的月餅',                          'bVEwqxv2pac', 'bVEwqxv2pac'),
    (12, '12', 'individual', 12, N'菜園旁的幸福食堂',                      'eC-ZaOIhfNs', 'lr0hRKBrr34'),
    (13, '13', 'individual', 13, N'自己種，安心又好吃',                    'y1CcH9lENsg', 'pWeOqIiWU-o'),
    (14, '14', 'team',       1,  N'芒果樹葉拓印團體創作',                  'XcyBVVrgtZ4', 'XcyBVVrgtZ4'),
    (15, '15', 'team',       2,  N'韭菜蛋餅勁好吃',                        'F-yG_RP_7MU', '4jpB-CSAyQ8'),
    (16, '16', 'team',       3,  N'我們的日子，都是一起過的',              'oA2tq7b6pxE', 'OK61Jr3SSnE'),
    (17, '17', 'team',       4,  N'一新有您真好',                          '-gCYY0_qysA', 'a6Wbk2emEfo'),
    (18, '18', 'team',       5,  N'來去雲林口湖蚵寮吃海味',                '1LhVjVY0860', 'gI5M1juxdv8'),
    (19, '19', 'team',       6,  N'《走進田心，綠色照顧就在生活裡》',      'yxSiup9ROkU', '1dHeovJfc8Y'),
    (20, '20', 'team',       7,  N'嘉苳社區音樂療育非洲鼓的日常',          '5IS92BnoN30', 'PBHXTTCdjUc'),
    (21, '21', 'team',       8,  N'編織藺草',                              '79O2-Cj55Dg', '-hJZVqdovz0'),
    (22, '22', 'team',       9,  N'從鋤頭到畫筆 借歲月繪時光',             'KnxmPA4Stc0', 'snVd2CNRZ8w'),
    (23, '23', 'team',       10, N'水井仔',                                'btzPCWLCfAc', 'IzoDIJ1LdjI'),
    (24, '24', 'team',       11, N'米香、水牛、綠照香：池上富興的守護好時光','9qmAlMFuJbo', '_LRR7qkMeyA'),
    (25, '25', 'team',       12, N'手指動一動',                            '2Bq0BtDgPyc', 'E-Db28WVeMg'),
    (26, '26', 'team',       13, N'長者的綠菜園',                          'qhvyD0d5vyM', 'YYkTqr-DkUw'),
    (27, '27', 'team',       14, N'米棧社區-就是不一樣不一樣',             'L2LUywDVpA0', 'HHTJ-bpVxwY');

IF (SELECT COUNT(*) FROM @Videos) <> 27
    THROW 51131, 'Expected exactly 27 approved video rows.', 1;

IF EXISTS
(
    SELECT NewYouTubeId
    FROM @Videos
    GROUP BY NewYouTubeId
    HAVING COUNT(*) > 1
)
    THROW 51132, 'Approved YouTube IDs contain a duplicate.', 1;

IF EXISTS
(
    SELECT 1
    FROM @Videos AS expected
    LEFT JOIN dbo.Videos AS video ON video.Id = expected.Id
    WHERE video.Id IS NULL
       OR video.Number <> expected.Number
       OR video.Category <> expected.Category
       OR video.SortOrder <> expected.SortOrder
       OR video.Title <> expected.Title
       OR video.IsActive <> 1
       OR video.YouTubeId NOT IN (expected.PreviousYouTubeId, expected.NewYouTubeId)
)
    THROW 51133, 'Database metadata or current YouTube ID differs from the approved source. Nothing was changed.', 1;

SELECT
    video.Number,
    video.Title,
    video.YouTubeId AS CurrentYouTubeId,
    expected.NewYouTubeId,
    CASE WHEN video.YouTubeId = expected.NewYouTubeId THEN N'ALREADY APPLIED' ELSE N'WILL UPDATE' END AS Action
FROM @Videos AS expected
INNER JOIN dbo.Videos AS video ON video.Id = expected.Id
ORDER BY video.Id;

IF @ApplyChanges = 0
BEGIN
    PRINT N'PREVIEW ONLY. Nothing was changed.';
    RETURN;
END;

IF @Confirmation <> @RequiredConfirmation
    THROW 51134, 'Confirmation is missing or incorrect. Nothing was changed.', 1;

DECLARE @ExpectedUpdates int =
(
    SELECT COUNT(*)
    FROM @Videos AS expected
    INNER JOIN dbo.Videos AS video ON video.Id = expected.Id
    WHERE video.YouTubeId = expected.PreviousYouTubeId
      AND video.YouTubeId <> expected.NewYouTubeId
);

BEGIN TRY
    BEGIN TRANSACTION;

    UPDATE video
    SET YouTubeId = expected.NewYouTubeId
    FROM dbo.Videos AS video
    INNER JOIN @Videos AS expected ON expected.Id = video.Id
    WHERE video.YouTubeId = expected.PreviousYouTubeId
      AND video.YouTubeId <> expected.NewYouTubeId;

    IF @@ROWCOUNT <> @ExpectedUpdates
        THROW 51135, 'The updated row count differs from the validated preview; the transaction will be rolled back.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM @Videos AS expected
        INNER JOIN dbo.Videos AS video ON video.Id = expected.Id
        WHERE video.YouTubeId <> expected.NewYouTubeId
    )
        THROW 51136, 'Post-update verification failed; the transaction will be rolled back.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT video.Number, video.Title, video.YouTubeId AS AppliedYouTubeId
FROM @Videos AS expected
INNER JOIN dbo.Videos AS video ON video.Id = expected.Id
ORDER BY video.Id;

PRINT CONCAT(N'YouTube ID refresh succeeded. Updated rows: ', @ExpectedUpdates, N'.');
GO
