SET NOCOUNT ON;
SET XACT_ABORT ON;

/*
  Replace only the VALUES rows with the final owner-approved catalog.
  Keep @ApplyChanges = 0 for the first rehearsal; it always rolls back.
*/
DECLARE @ApplyChanges bit = 0;
DECLARE @Confirmation nvarchar(100) = N'';

IF DB_NAME() IN (N'master', N'model', N'msdb', N'tempdb')
    THROW 50901, 'Refusing to replace the catalog in a system database.', 1;
IF OBJECT_ID(N'dbo.Videos', N'U') IS NULL
   OR NOT EXISTS (SELECT 1 FROM dbo.SchemaVersions WHERE VersionNumber = '003')
    THROW 50902, 'Video catalog schema 003 is not installed.', 1;

DECLARE @OfficialVideos TABLE
(
    Id tinyint NOT NULL PRIMARY KEY,
    Number char(2) NOT NULL UNIQUE,
    Title nvarchar(200) NOT NULL,
    Team nvarchar(200) NOT NULL,
    YoutubeId varchar(32) NOT NULL,
    Poster nvarchar(500) NOT NULL,
    Category varchar(10) NOT NULL,
    SortOrder tinyint NOT NULL,
    UNIQUE (Category, SortOrder)
);

/* EDIT THIS VALUES SECTION ONLY. Current rows are Demo data for dry-run testing. */
INSERT @OfficialVideos (Id, Number, Title, Team, YoutubeId, Poster, Category, SortOrder)
VALUES
    (1,  '01', N'晨光裡的慢生活',   N'暖陽創作',   'YLi5uuy5bw4', N'images/posters/individual-demo.jpg', 'individual', 1),
    (2,  '02', N'田園散步日記',     N'青禾影像',   'YLi5uuy5bw4', N'images/posters/individual-demo.jpg', 'individual', 2),
    (3,  '03', N'陪伴的溫度',       N'微光小隊',   'YLi5uuy5bw4', N'images/posters/individual-demo.jpg', 'individual', 3),
    (4,  '04', N'家鄉的好時光',     N'拾光製作',   'YLi5uuy5bw4', N'images/posters/individual-demo.jpg', 'individual', 4),
    (5,  '05', N'綠意生活提案',     N'日常映畫',   'YLi5uuy5bw4', N'images/posters/individual-demo.jpg', 'individual', 5),
    (6,  '06', N'午後的一杯茶',     N'慢慢工作室', 'YLi5uuy5bw4', N'images/posters/individual-demo.jpg', 'individual', 6),
    (7,  '07', N'記憶中的菜園',     N'好日攝影',   'YLi5uuy5bw4', N'images/posters/individual-demo.jpg', 'individual', 7),
    (8,  '08', N'一起曬太陽',       N'晴天企劃',   'YLi5uuy5bw4', N'images/posters/individual-demo.jpg', 'individual', 8),
    (9,  '09', N'巷口的人情味',     N'鄰里視角',   'YLi5uuy5bw4', N'images/posters/individual-demo.jpg', 'individual', 9),
    (10, '10', N'歲月靜好的模樣',   N'年輪影像',   'YLi5uuy5bw4', N'images/posters/individual-demo.jpg', 'individual', 10),
    (11, '11', N'幸福正在發芽',     N'小芽創意',   'YLi5uuy5bw4', N'images/posters/individual-demo.jpg', 'individual', 11),
    (12, '12', N'土地教我的事',     N'沃土紀錄',   'YLi5uuy5bw4', N'images/posters/individual-demo.jpg', 'individual', 12),
    (13, '13', N'熟悉的笑容',       N'笑顏製作',   'YLi5uuy5bw4', N'images/posters/individual-demo.jpg', 'individual', 13),
    (14, '14', N'把日子種成花',     N'花間影像',   'YLi5uuy5bw4', N'images/posters/individual-demo.jpg', 'individual', 14),
    (15, '15', N'回家的那條路',     N'歸途工作室', 'YLi5uuy5bw4', N'images/posters/individual-demo.jpg', 'individual', 15),
    (16, '16', N'共好的一百種可能', N'共好行動隊', 'gDQk3jAY67U', N'images/posters/team-demo.jpg', 'team', 1),
    (17, '17', N'攜手打造綠生活',   N'綠動聯盟',   'gDQk3jAY67U', N'images/posters/team-demo.jpg', 'team', 2),
    (18, '18', N'我們的社區日常',   N'厝邊製作社', 'gDQk3jAY67U', N'images/posters/team-demo.jpg', 'team', 3),
    (19, '19', N'銀髮活力進行式',   N'青春不打烊', 'gDQk3jAY67U', N'images/posters/team-demo.jpg', 'team', 4),
    (20, '20', N'一桌好菜的故事',   N'幸福餐桌隊', 'gDQk3jAY67U', N'images/posters/team-demo.jpg', 'team', 5),
    (21, '21', N'讓陪伴成為日常',   N'暖心夥伴',   'gDQk3jAY67U', N'images/posters/team-demo.jpg', 'team', 6),
    (22, '22', N'社區裡的新風景',   N'地方放送局', 'gDQk3jAY67U', N'images/posters/team-demo.jpg', 'team', 7),
    (23, '23', N'跨世代同樂會',     N'三代同堂隊', 'gDQk3jAY67U', N'images/posters/team-demo.jpg', 'team', 8),
    (24, '24', N'綠色照顧向前行',   N'綠照實踐家', 'gDQk3jAY67U', N'images/posters/team-demo.jpg', 'team', 9),
    (25, '25', N'田野間的歡笑聲',   N'田間放映會', 'gDQk3jAY67U', N'images/posters/team-demo.jpg', 'team', 10),
    (26, '26', N'小村大幸福',       N'幸福小村隊', 'gDQk3jAY67U', N'images/posters/team-demo.jpg', 'team', 11),
    (27, '27', N'一起變老也很好',   N'不老夢想團', 'gDQk3jAY67U', N'images/posters/team-demo.jpg', 'team', 12),
    (28, '28', N'從土地長出的力量', N'土地共學社', 'gDQk3jAY67U', N'images/posters/team-demo.jpg', 'team', 13),
    (29, '29', N'好厝邊好生活',     N'好厝邊聯盟', 'gDQk3jAY67U', N'images/posters/team-demo.jpg', 'team', 14),
    (30, '30', N'共築幸福新日常',   N'共築影像團', 'gDQk3jAY67U', N'images/posters/team-demo.jpg', 'team', 15);

IF (SELECT COUNT(*) FROM @OfficialVideos) <> 30
    THROW 50903, 'Exactly 30 official videos are required.', 1;
IF EXISTS
(
    SELECT 1 FROM @OfficialVideos
    WHERE Id NOT BETWEEN 1 AND 30
       OR Number <> RIGHT('0' + CONVERT(varchar(2), Id), 2)
       OR (Id BETWEEN 1 AND 15 AND (Category <> 'individual' OR SortOrder <> Id))
       OR (Id BETWEEN 16 AND 30 AND (Category <> 'team' OR SortOrder <> Id - 15))
       OR NULLIF(LTRIM(RTRIM(Title)), N'') IS NULL
       OR NULLIF(LTRIM(RTRIM(Team)), N'') IS NULL
       OR NULLIF(LTRIM(RTRIM(YoutubeId)), '') IS NULL
       OR NULLIF(LTRIM(RTRIM(Poster)), N'') IS NULL
)
    THROW 50904, 'Official video rows failed validation.', 1;

IF @ApplyChanges = 1
BEGIN
    IF @Confirmation <> N'REPLACE GREENCARE VIDEO CATALOG'
        THROW 50905, 'Set the exact confirmation phrase before applying.', 1;
    IF EXISTS (SELECT 1 FROM dbo.WatchSessions) OR EXISTS (SELECT 1 FROM dbo.Votes)
        THROW 50906, 'Catalog replacement is blocked because watch or vote records already exist.', 1;
END;

BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE target
       SET Number = source.Number, Title = source.Title, Team = source.Team,
           YoutubeId = source.YoutubeId, Poster = source.Poster,
           Category = source.Category, SortOrder = source.SortOrder,
           IsActive = 1, UpdatedAtUtc = SYSUTCDATETIME()
    FROM dbo.Videos AS target
    INNER JOIN @OfficialVideos AS source ON source.Id = target.Id;

    IF @@ROWCOUNT <> 30 OR (SELECT COUNT(*) FROM dbo.Videos) <> 30
        THROW 50907, 'Target Videos must contain exactly the same 30 identities.', 1;

    SELECT Id, Number, Title, Team, Category, SortOrder, YoutubeId, Poster, IsActive
    FROM dbo.Videos ORDER BY Id;

    IF @ApplyChanges = 1
    BEGIN
        COMMIT TRANSACTION;
        PRINT 'Official video catalog replacement committed successfully.';
    END
    ELSE
    BEGIN
        ROLLBACK TRANSACTION;
        PRINT 'DRY RUN passed. All changes were rolled back.';
    END;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
