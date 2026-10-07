SET NOCOUNT ON;
SET XACT_ABORT ON;

/*
  First run: keep @ApplyChanges = 0. The script validates and rolls back.
  Apply run: set @ApplyChanges = 1 and enter the exact confirmation phrase.
*/
DECLARE @ApplyChanges bit = 0;
DECLARE @Confirmation nvarchar(100) = N'';

IF DB_NAME() IN (N'master', N'model', N'msdb', N'tempdb')
    THROW 51501, 'Refusing to replace the catalog in a system database.', 1;
IF OBJECT_ID(N'dbo.Videos', N'U') IS NULL
   OR NOT EXISTS (SELECT 1 FROM dbo.SchemaVersions WHERE VersionNumber = '005')
    THROW 51502, 'Dynamic video catalog schema 005 is not installed.', 1;

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

INSERT @OfficialVideos (Id, Number, Title, Team, YoutubeId, Poster, Category, SortOrder)
VALUES
    (1,  '01', N'看到你心花開',                         N'新竹市東區水源社區發展協會',                         '8XyWphPLAxg', N'images/posters/official/01.jpg', 'individual', 1),
    (2,  '02', N'亭亭玉立的金治',                       N'臺中市神岡區溪洲社區發展協會',                       'UwKr9613to0', N'images/posters/official/02.jpg', 'individual', 2),
    (3,  '03', N'蝶舞綠照，樂活新生活',                 N'苗栗縣竹南鎮塭內社區發展協會',                       'KLGkxFwtlw4', N'images/posters/official/03.jpg', 'individual', 3),
    (4,  '04', N'小鐵馬的愛',                           N'苗栗縣後龍鎮埔頂社區發展協會',                       'Qv0BV1M4Iog', N'images/posters/official/04.jpg', 'individual', 4),
    (5,  '05', N'種下智慧，收獲幸福',                   N'苗栗縣竹南鎮塭內社區發展協會',                       'V-l94W68bzw', N'images/posters/official/05.jpg', 'individual', 5),
    (6,  '06', N'認識枇杷社區不彎腰菜園',               N'社團法人南投縣埔里鎮枇杷社區發展協會',               '_Twv1vyVCRw', N'images/posters/official/06.jpg', 'individual', 6),
    (7,  '07', N'爺的掃把',                             N'南投縣埔里鎮一新社區發展協會',                       'jBmbSjhnEkM', N'images/posters/official/07.jpg', 'individual', 7),
    (8,  '08', N'學習製作愛玉',                         N'臺南市後壁區菁寮社區發展協會',                       'Mv3c-2vxwik', N'images/posters/official/08.jpg', 'individual', 8),
    (9,  '09', N'優游自在的沈愛姐',                     N'屏東縣萬丹鄉社中社區發展協會',                       'M0umYSS_n4M', N'images/posters/official/09.jpg', 'individual', 9),
    (10, '10', N'有伴的日子，真好',                     N'社團法人中華民國慈惠善導書院文化教育研究協會',       'L3xhH2Q93dY', N'images/posters/official/10.jpg', 'individual', 10),
    (11, '11', N'阿綢姐的月餅',                         N'屏東縣萬丹鄉社中社區發展協會',                       'bVEwqxv2pac', N'images/posters/official/11.jpg', 'individual', 11),
    (12, '12', N'菜園旁的幸福食堂',                     N'高雄市旗山區糖廠社區發展協會',                       'eC-ZaOIhfNs', N'images/posters/official/12.jpg', 'individual', 12),
    (13, '13', N'自己種，安心又好吃',                   N'台東縣池上鄉萬安社區發展協會',                       'y1CcH9lENsg', N'images/posters/official/13.jpg', 'individual', 13),
    (14, '14', N'芒果樹葉拓印團體創作',                 N'新竹市東區水源社區發展協會',                         'XcyBVVrgtZ4', N'images/posters/official/14.jpg', 'team', 1),
    (15, '15', N'韭菜蛋餅勁好吃',                       N'宜蘭縣員山鄉同樂社區發展協會',                       'F-yG_RP_7MU', N'images/posters/official/15.jpg', 'team', 2),
    (16, '16', N'我們的日子，都是一起過的',             N'苗栗縣藝耆協會',                                     'oA2tq7b6pxE', N'images/posters/official/16.jpg', 'team', 3),
    (17, '17', N'一新有您真好',                         N'南投縣埔里鎮一新社區發展協會',                       '-gCYY0_qysA', N'images/posters/official/17.jpg', 'team', 4),
    (18, '18', N'來去雲林口湖蚵寮吃海味',               N'雲林縣口湖鄉社區產業生態發展協會',                   '1LhVjVY0860', N'images/posters/official/18.jpg', 'team', 5),
    (19, '19', N'《走進田心，綠色照顧就在生活裡》',     N'社團法人雲林縣老人長期照護協會',                     'yxSiup9ROkU', N'images/posters/official/19.jpg', 'team', 6),
    (20, '20', N'嘉苳社區音樂療育非洲鼓的日常',         N'臺南市後壁區嘉苳社區發展協會',                       '5IS92BnoN30', N'images/posters/official/20.jpg', 'team', 7),
    (21, '21', N'編織藺草',                             N'臺南市後壁區菁寮社區發展協會',                       '79O2-Cj55Dg', N'images/posters/official/21.jpg', 'team', 8),
    (22, '22', N'從鋤頭到畫筆 借歲月繪時光',            N'屏東縣佳冬鄉塭豐社區發展協會',                       'KnxmPA4Stc0', N'images/posters/official/22.jpg', 'team', 9),
    (23, '23', N'水井仔',                               N'臺東縣關山鎮豐泉社區發展協會',                       'btzPCWLCfAc', N'images/posters/official/23.jpg', 'team', 10),
    (24, '24', N'米香、水牛、綠照香：池上富興的守護好時光', N'臺東縣池上鄉富興社區發展協會',                    '9qmAlMFuJbo', N'images/posters/official/24.jpg', 'team', 11),
    (25, '25', N'手指動一動',                           N'花蓮縣玉里鎮樂合社區發展協會',                       '2Bq0BtDgPyc', N'images/posters/official/25.jpg', 'team', 12),
    (26, '26', N'長者的綠菜園',                         N'社團法人花蓮縣織羅部落文化傳承經濟發展協會',         'qhvyD0d5vyM', N'images/posters/official/26.jpg', 'team', 13),
    (27, '27', N'米棧社區-就是不一樣不一樣',             N'花蓮縣壽豐鄉米棧社區發展協會',                       'L2LUywDVpA0', N'images/posters/official/27.jpg', 'team', 14);

IF (SELECT COUNT(*) FROM @OfficialVideos) <> 27
    THROW 51503, 'Exactly 27 official videos are required for the 2026 catalog.', 1;
IF (SELECT COUNT(*) FROM @OfficialVideos WHERE Category = 'individual') <> 13
   OR (SELECT COUNT(*) FROM @OfficialVideos WHERE Category = 'team') <> 14
    THROW 51504, 'Expected 13 individual and 14 team videos.', 1;
IF EXISTS
(
    SELECT 1 FROM @OfficialVideos
    WHERE Number <> RIGHT('0' + CONVERT(varchar(2), Id), 2)
       OR NULLIF(LTRIM(RTRIM(Title)), N'') IS NULL
       OR NULLIF(LTRIM(RTRIM(Team)), N'') IS NULL
       OR NULLIF(LTRIM(RTRIM(YoutubeId)), '') IS NULL
       OR NULLIF(LTRIM(RTRIM(Poster)), N'') IS NULL
       OR SortOrder = 0
)
    THROW 51505, 'One or more official rows failed validation.', 1;

IF @ApplyChanges = 1
BEGIN
    IF @Confirmation <> N'APPLY 2026 GREENCARE OFFICIAL CATALOG'
        THROW 51506, 'Set the exact confirmation phrase before applying.', 1;
    IF EXISTS (SELECT 1 FROM dbo.WatchSessions) OR EXISTS (SELECT 1 FROM dbo.Votes)
        THROW 51507, 'Official catalog activation requires an empty activity database.', 1;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    IF EXISTS (SELECT 1 FROM dbo.Videos WHERE SortOrder > 155)
        THROW 51508, 'Existing sort orders cannot be moved into the temporary range.', 1;

    UPDATE dbo.Videos
       SET SortOrder = SortOrder + 100,
           UpdatedAtUtc = SYSUTCDATETIME();

    UPDATE target
       SET Number = source.Number,
           Title = source.Title,
           Team = source.Team,
           YoutubeId = source.YoutubeId,
           Poster = source.Poster,
           Category = source.Category,
           SortOrder = source.SortOrder,
           IsActive = 1,
           UpdatedAtUtc = SYSUTCDATETIME()
    FROM dbo.Videos AS target
    INNER JOIN @OfficialVideos AS source ON source.Id = target.Id;

    INSERT dbo.Videos
        (Id, Number, Title, Team, YoutubeId, Poster, Category, SortOrder, IsActive)
    SELECT source.Id, source.Number, source.Title, source.Team, source.YoutubeId,
           source.Poster, source.Category, source.SortOrder, 1
    FROM @OfficialVideos AS source
    WHERE NOT EXISTS (SELECT 1 FROM dbo.Videos AS target WHERE target.Id = source.Id);

    UPDATE target
       SET IsActive = 0,
           UpdatedAtUtc = SYSUTCDATETIME()
    FROM dbo.Videos AS target
    WHERE NOT EXISTS (SELECT 1 FROM @OfficialVideos AS source WHERE source.Id = target.Id);

    IF (SELECT COUNT(*) FROM dbo.Videos WHERE IsActive = 1) <> 27
       OR (SELECT COUNT(*) FROM dbo.Videos WHERE IsActive = 1 AND Category = 'individual') <> 13
       OR (SELECT COUNT(*) FROM dbo.Videos WHERE IsActive = 1 AND Category = 'team') <> 14
        THROW 51509, 'The active catalog does not match the approved 27-work layout.', 1;

    SELECT Id, Number, Title, Team, Category, SortOrder, YoutubeId, Poster, IsActive
    FROM dbo.Videos
    ORDER BY IsActive DESC, Category, SortOrder;

    IF @ApplyChanges = 1
    BEGIN
        COMMIT TRANSACTION;
        PRINT '2026 official video catalog committed successfully.';
    END
    ELSE
    BEGIN
        ROLLBACK TRANSACTION;
        PRINT 'DRY RUN passed. All catalog changes were rolled back.';
    END;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
