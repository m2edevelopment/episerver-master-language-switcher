﻿USE [EpiserverDb]
GO
/****** Object:  StoredProcedure [dbo].[cogChangePageBranchMasterLanguage]    Script Date: 20/08/2018 10:27:07 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[cogChangePageBranchMasterLanguage]
	@page_id	int,
	@language_branch varchar(20),
	@recursive bit,
	@switch_only bit
AS

DECLARE @language_branch_id nchar(17);
DECLARE @language_branch_nid int;
DECLARE @prev_language_branch_nid int;
DECLARE @child_Id int;
DECLARE @Fetch int;
DECLARE @target_lang_version_exist int;

SET @language_branch_nid = (SELECT pkID FROM tblLanguageBranch WHERE (LanguageID = @language_branch))
SET @language_branch_id = (SELECT LanguageId FROM tblLanguageBranch WHERE (LanguageID = @language_branch))
SET @prev_language_branch_nid = (SELECT fkMasterLanguageBranchID FROM tblContent WHERE pkId = @page_id)
SET @target_lang_version_exist = (SELECT count(*) FROM tblContentLanguage WHERE (fkContentID = @page_id AND fkLanguageBranchID = @language_branch_nid))


IF 1 = @switch_only 
  BEGIN
	print 'target_lang_version_exist' + str(@target_lang_version_exist);
	IF @target_lang_version_exist > 0
	BEGIN
	UPDATE tblContent
		SET fkMasterLanguageBranchID = @language_branch_nid
		WHERE pkID = @page_id AND fkMasterLanguageBranchID = @prev_language_branch_nid
	END
	ELSE
	BEGIN
	RAISERROR 
	(N'The Selected page with ID:%d, cannot switch master branch since there is no version in the selected target language: %s.',
    11, 1, @page_id,  @language_branch); 
	END
  END
ELSE
  BEGIN
	IF @target_lang_version_exist > 0
	BEGIN
	  RAISERROR 
	    (N'The Selected page with ID:%d, cannot be translated since there already is a version in the selected target language: %s.',
        11, 1, @page_id,  @language_branch); 
	  END
	ELSE
	  BEGIN
		UPDATE tblContent
		   SET
			  fkMasterLanguageBranchID = @language_branch_nid
		 WHERE pkId = @page_id

		UPDATE tblContentProperty
			SET fkLanguageBranchID = @language_branch_nid
		 WHERE fkContentID = @page_id AND fkLanguageBranchID = @prev_language_branch_nid

		UPDATE tblContentLanguage
		   SET fkLanguageBranchID = @language_branch_nid
		WHERE fkContentID = @page_id AND fkLanguageBranchID = @prev_language_branch_nid

		UPDATE tblWorkContent
		   SET fkLanguageBranchID = @language_branch_nid
		WHERE fkContentID = @page_id AND fkLanguageBranchID = @prev_language_branch_nid
	  END
  END

IF 1 = @recursive 
BEGIN
	DECLARE children_cursor CURSOR LOCAL FOR
		select pkId from tblContent where fkParentId = @page_id

	OPEN children_cursor

	FETCH NEXT FROM children_cursor INTO @child_Id
	SET @Fetch=@@FETCH_STATUS

	WHILE @Fetch = 0
	BEGIN
		print @child_id
		print @language_branch_id
		exec [dbo].[cogChangePageBranchMasterLanguage] @child_id, @language_branch_id, @recursive, @switch_only
		FETCH NEXT FROM children_cursor INTO @child_Id
		SET @Fetch=@@FETCH_STATUS
	END

	CLOSE children_cursor
	DEALLOCATE children_cursor
END
GO
/****** Object:  StoredProcedure [dbo].[cogGetContentBlocks]    Script Date: 20/08/2018 10:27:07 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[cogGetContentBlocks]
	-- Add the parameters for the stored procedure here
	@page_id int
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	SELECT tblContent.pkID, tblContent.ContentType from tblContent
INNER JOIN tblContentSoftlink ON tblContent.ContentGUID = tblContentSoftlink.fkReferencedContentGUID
WHERE tblContentSoftlink.fkOwnerContentID = @page_id AND tblContent.ContentType = 1
ORDER BY tblContent.pkID
END
GO
/****** Object:  StoredProcedure [dbo].[cogGetContentHierarchy]    Script Date: 20/08/2018 10:27:07 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[cogGetContentHierarchy]
	@page_id	int
AS
BEGIN

	SET NOCOUNT ON;

    WITH content
AS ( 
SELECT Parent.pkID, Parent.ContentGUID, Parent.ContentType, Parent.fkParentID
FROM tblContent As Parent
WHERE Parent.pkID = @page_id

UNION ALL

SELECT Child.pkID, Child.ContentGUID, Child.ContentType, Child.fkParentID
FROM tblContent as Child
INNER JOIN content 
ON Child.fkParentID = content.pkID
WHERE Child.fkParentID IS NOT NULL )
SELECT *
FROM content
ORDER BY content.pkID
	
END
GO
