/*
	Only execute the script  when the correct schema is selected

*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [DEV00].[BB_BALANCE_VALIDATION] 
(	
	@YBATNBR VARCHAR(25)
)
AS
BEGIN
	
	DECLARE @DEBSUM INT,
			@CRDSUM INT,
			@MINTRANSNBR INT,
			@MAXTRANSNBR INT,
			@MAXLIGCOUNT INT,
			@MINLIGCOUNT INT
	
	SELECT @MAXTRANSNBR = MAX(YTRANSNBR_0) FROM YBBDETAILTEM WHERE YBATNBR_0 = @YBATNBR
	SELECT @MINTRANSNBR = MIN(YTRANSNBR_0) FROM YBBDETAILTEM WHERE YBATNBR_0 = @YBATNBR
	
	WHILE @MINTRANSNBR <= @MAXTRANSNBR
	BEGIN	
	print @MINTRANSNBR
		-- CHECK BALANCE = 0
		SELECT @DEBSUM = SUM(YDEB_0), @CRDSUM = SUM(YCDT_0)
		FROM YBBDETAIL
		WHERE YBATNBR_0 = @YBATNBR AND YTRANSNBR_0 = @MINTRANSNBR

		select @DEBSUM,@CRDSUM
		 
		IF @DEBSUM - @CRDSUM <> 0
		BEGIN
			-- WRITE ERROR LINE
			-- PRINT 'BALANCE NOT 0' -- DEBUG
			SELECT @MAXLIGCOUNT = MAX(YDETLIG_0) FROM YBBDETAILTEM WHERE YBATNBR_0 = @YBATNBR AND YTRANSNBR_0 = @MINTRANSNBR
			SELECT @MINLIGCOUNT = MIN(YDETLIG_0) FROM YBBDETAILTEM WHERE YBATNBR_0 = @YBATNBR AND YTRANSNBR_0 = @MINTRANSNBR
			WHILE @MINLIGCOUNT <= @MAXLIGCOUNT
			BEGIN
				--SELECT [YBATNBR_0],[YBATNBR_0]+'-'+CAST(YDETLIG_0 AS VARCHAR(10))[YSRC_0],[YDETLIG_0],[YFCY_0],[YENTTYP_0],[YJOU_0],
				--	   [YDETDES_0],[YACC_0],[YLIGDES_0],'BALANCE DOES NOT EQUAL TO 0'[MESSAGE],[YDETLIG_0] 
				UPDATE YBBDETAILTEM 				
				SET YRESVAL_0 = 'BAL1'
				WHERE YBATNBR_0 = @YBATNBR AND YTRANSNBR_0 = @MINTRANSNBR AND YDETLIG_0 = @MINLIGCOUNT
				SET @MINLIGCOUNT += 1
			END
		END	
		SET @MINTRANSNBR += 1
	END
	
	
END
GO
/****** Object:  StoredProcedure [DEV00].[BB_CASH_TRANSACTION_VALIDATION]    Script Date: 13/12/2018 11:48:15 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [DEV00].[BB_CASH_TRANSACTION_VALIDATION] 
(	
	@YBATNBR VARCHAR(25)	
)
AS
BEGIN

	DECLARE @BATTYP INT,
		    @MINTRANSNBR INT,
			@MAXTRANSNBR INT,
			@MAXFCYCOUNT INT,
			@BANKCOUNT	 INT,
			@DETLIGMIN   INT,
			@DETLIGMAX   INT,
			@BANELA		 VARCHAR(50),
			@ELAPATH	 VARCHAR(250),
			@BANVALUE	 VARCHAR(25),
			@LIGCOUNT	 INT


	SELECT @MAXTRANSNBR = MAX(YTRANSNBR_0) FROM YBBDETAILTEM WHERE YBATNBR_0 = @YBATNBR
	SELECT @MINTRANSNBR = MIN(YTRANSNBR_0) FROM YBBDETAILTEM WHERE YBATNBR_0 = @YBATNBR

	WHILE @MINTRANSNBR <= @MAXTRANSNBR
	BEGIN
		SELECT @BATTYP = YBATTYP_0 from YBBDETAILTEM Where YTRANSNBR_0 = @MINTRANSNBR AND YBATNBR_0 = @YBATNBR
		IF @BATTYP = 2
		BEGIN
			-- DISTINCT BANK A/C = 2
			SELECT @BANKCOUNT = COUNT(DISTINCT(YBAN_0)) FROM YBBDETAILTEM WHERE YTRANSNBR_0 = @MINTRANSNBR AND YBATNBR_0 = @YBATNBR AND YBATTYP_0 = @BATTYP
			IF @BANKCOUNT <= 2 
			BEGIN
				-- TRANSACTION LINE COUNT = 2				 
				SELECT @LIGCOUNT = COUNT(*) FROM YBBDETAILTEM WHERE YTRANSNBR_0 = @MINTRANSNBR AND YBATNBR_0 = @YBATNBR AND YBATTYP_0 = @BATTYP
				IF @LIGCOUNT <= 2
				BEGIN
					-- ALL BANK ACCOUNTS ARE ACTIVE
					SELECT @DETLIGMAX = MAX(YDETLIG_0) FROM YBBDETAILTEM WHERE YBATNBR_0 = @YBATNBR AND YTRANSNBR_0 = @MINTRANSNBR
					SELECT @DETLIGMIN = MIN(YDETLIG_0) FROM YBBDETAILTEM WHERE YBATNBR_0 = @YBATNBR AND YTRANSNBR_0 = @MINTRANSNBR
					WHILE @DETLIGMIN <= @DETLIGMAX
					BEGIN
						SELECT @BANVALUE = YBAN_0 FROM YBBDETAILTEM WHERE YTRANSNBR_0 = @MINTRANSNBR AND YBATNBR_0 = @YBATNBR AND YDETLIG_0 = @DETLIGMIN
						IF @BANVALUE <> ''
						BEGIN
							IF (SELECT YSTA_0 FROM BANK WHERE BAN_0 = @BANVALUE) = 2
							BEGIN
								-- PRINCIPAL BANK ACCOUNT
								IF (SELECT YBANPRNSTA_0 FROM BANK WHERE BAN_0 IN (SELECT YBAN_0 FROM YBBDETAILTEM WHERE YBATNBR_0 = @YBATNBR AND YBATTYP_0 = @BATTYP AND YDETLIG_0 = @DETLIGMIN)) = 2
								BEGIN
									UPDATE YBBDETAILTEM
									SET YRESVAL_0 = 'BPASSPRI' -- BANK ACCOUNT PRIMARY BANK --> WRITE SIMULATION LINE
									WHERE YBATNBR_0 = @YBATNBR AND YDETLIG_0 = @DETLIGMIN
								END
								ELSE
								BEGIN
									IF	(SELECT ISNULL(YELA_0,'') FROM BANK WHERE BAN_0 IN (SELECT YBAN_0 FROM YBBDETAILTEM WHERE YBATNBR_0 = @YBATNBR AND YTRANSNBR_0 = @MINTRANSNBR AND YDETLIG_0 = @DETLIGMIN)) = '' OR
										(SELECT ISNULL(YELABAN_0,'') FROM BANK WHERE BAN_0 IN (SELECT YBAN_0 FROM YBBDETAILTEM WHERE YBATNBR_0 = @YBATNBR AND YTRANSNBR_0 = @MINTRANSNBR AND YDETLIG_0 = @DETLIGMIN)) = ''
									BEGIN
										UPDATE YBBDETAILTEM
										SET YRESVAL_0 = 'BANELA' -- BANK ELA IS NOT SETUP CORRECTLY
										WHERE YBATNBR_0 = @YBATNBR AND YDETLIG_0 = @DETLIGMIN
									END
									ELSE
									BEGIN
										SELECT @BANELA = YELA_0 FROM BANK WHERE BAN_0 IN (SELECT YBAN_0 FROM YBBDETAILTEM WHERE YBATNBR_0 = @YBATNBR AND YDETLIG_0 = @DETLIGMIN)
										EXEC [BB_ELA_PATH_VALIDATION] @BANELA
										EXEC [BB_ELA_BANK_VALIDATION] @BANVALUE, @BANELA

										SELECT @ELAPATH = YELAPATH_0 FROM YICELA WHERE YELASTR_0 = @BANELA

										UPDATE YBBDETAILTEM
										SET YELA_0 = @BANELA, YRESVAL_0 = 'BPASSELA' -- ELA PATH WILL BE USED TO WRITE SIMULATION LINES (DR/CR) --> WRITE SIMULATION LINES
										WHERE YBATNBR_0 = @YBATNBR AND YDETLIG_0 = @DETLIGMIN
																				
									END
								END
							END
							ELSE
							BEGIN
								UPDATE YBBDETAILTEM
								SET YRESVAL_0 = 'BACT1' -- BANK ACCOUNT SELECT IS NOT ACTIVE
								WHERE YTRANSNBR_0 = @MINTRANSNBR AND YBATNBR_0 = @YBATNBR AND YDETLIG_0 = @DETLIGMIN
							END
						END
					SET @DETLIGMIN += 1
					END			
				END
				ELSE
				BEGIN
					UPDATE YBBDETAILTEM
					SET YRESVAL_0 = 'BREQ1' -- 2 OR LESS DISTINCT TRANSACTION LINES REQUIRED
					WHERE YTRANSNBR_0 = @MINTRANSNBR AND YBATNBR_0 = @YBATNBR
				END
			END
			ELSE
			BEGIN
				UPDATE YBBDETAILTEM
				SET YRESVAL_0 = 'BCNT1' -- CANNOT HAVE MORE THAN 2 DISTINCT BANK ACCOUNTS
				WHERE YTRANSNBR_0 = @MINTRANSNBR AND YBATNBR_0 = @YBATNBR
			END
		END
		SET @MINTRANSNBR += 1
	END	
END



GO
/****** Object:  StoredProcedure [DEV00].[BB_ELA_BANK_VALIDATION]    Script Date: 13/12/2018 11:48:15 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [DEV00].[BB_ELA_BANK_VALIDATION] 
(	
	@BANLIG VARCHAR(10),
	@YELALIG VARCHAR(50)
)
AS
BEGIN

	DECLARE @SRCBAN VARCHAR(10),
			@NXTSRCBAN VARCHAR(10),
			@YBANPRNSTA  INTEGER

	SELECT @SRCBAN = YELABAN_0 FROM BANK WHERE BAN_0 = @BANLIG	
	
	IF @SRCBAN <> ''
	BEGIN
		SELECT @NXTSRCBAN = YELABAN_0 FROM BANK WHERE BAN_0 = @SRCBAN 
		IF @NXTSRCBAN = ''
		BEGIN
			DELETE FROM [YBANELA] WHERE YELA_0 = @YELALIG
			INSERT INTO [YBANELA]([UPDTICK_0],[YBAN_0],[YELA_0],[YBANPRI_0],[YBANCPY_0],[CREDATTIM_0],[UPDDATTIM_0],[AUUID_0],[CREUSR_0],[UPDUSR_0],[YTREACC_0])
			SELECT 1, @SRCBAN, @YELALIG,YBANPRNSTA_0,CPY_0,GETDATE(), GETDATE(),NEWID(),'SQL','SQL',TREACC_0 FROM BANK WHERE BAN_0 = @SRCBAN
		END
		ELSE
		BEGIN
			WHILE @NXTSRCBAN <> ''
			BEGIN			
				SELECT @NXTSRCBAN = YELABAN_0 FROM BANK WHERE BAN_0 = @SRCBAN 
				IF @NXTSRCBAN <> ''
				BEGIN
					SET @SRCBAN = @NXTSRCBAN
				END	
			END
			DELETE FROM [YBANELA] WHERE YELA_0 = @YELALIG 
			INSERT INTO [YBANELA]([UPDTICK_0],[YBAN_0],[YELA_0],[YBANPRI_0],[YBANCPY_0],[CREDATTIM_0],[UPDDATTIM_0],[AUUID_0],[CREUSR_0],[UPDUSR_0],[YTREACC_0])
			SELECT 1, @SRCBAN, @YELALIG,YBANPRNSTA_0,CPY_0,GETDATE(), GETDATE(),NEWID(),'SQL','SQL',TREACC_0 FROM BANK WHERE BAN_0 = @SRCBAN
		END
	END
		
END

GO
/****** Object:  StoredProcedure [DEV00].[BB_ELA_PATH_FIND]    Script Date: 13/12/2018 11:48:15 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 -- EXEC [BB_ELA_PATH_FIND] 'MPL_DF_005_016_INT_2','MPL_DF_005_067_INT_2'
 -- 
CREATE PROCEDURE [DEV00].[BB_ELA_PATH_FIND] 
(	
	@ELA1 VARCHAR(50),
	@ELA2 VARCHAR(50),
	@ELAPATH VARCHAR(250) OUTPUT	
)
AS
BEGIN

	DECLARE @COUNTER INT,
			@ELAVAL VARCHAR(50),
			@VALFOUND INT,
			@ELAFOUND INT

	SET @COUNTER = 0 

	DECLARE ELA_PATH_FIND CURSOR FOR   
	SELECT value FROM YICELA
	CROSS APPLY STRING_SPLIT(YELAPATH_0,',')
	WHERE YELASTR_0 = @ELA1

	OPEN ELA_PATH_FIND
	
	FETCH NEXT FROM ELA_PATH_FIND   
	INTO @ELAVAL  
	
	--Check if ELA1 exist in ELA2 before running to avoid infinite loop
	SELECT @ELAFOUND = COUNT(*) FROM YICELA WHERE YELAPATH_0 LIKE '%'+@ELA1+'%' and YELASTR_0 = @ELA2
	--print cast(@ELAFOUND as varchar(100))
	IF @ELAFOUND > 0 
	BEGIN
		WHILE @COUNTER = 0  
		BEGIN 	
			-- Build new ELA path for amount of times until ELA value is found in the path
			IF @ELAPATH <> '' or @ELAPATH is not null
			BEGIN
				SET @ELAPATH = CONCAT(@ELAPATH,',',@ELAVAL)
			END
			ELSE IF @ELAPATH = ',' or @ELAPATH = '' or @ELAPATH is null
			BEGIN
				SET @ELAPATH = @ELAVAL
			END	

			SELECT @VALFOUND = COUNT(*) FROM YICELA WHERE YELAPATH_0 LIKE '%'+@ELAVAL+'%' and YELASTR_0 = @ELA2
			IF @VALFOUND <> 0
			BEGIN
				SET @COUNTER = 1
			END

			FETCH NEXT FROM ELA_PATH_FIND   
			INTO @ELAVAL 

		END   
	END
	CLOSE ELA_PATH_FIND;  
	DEALLOCATE ELA_PATH_FIND
	  		
END
GO
/****** Object:  StoredProcedure [DEV00].[BB_ELA_PATH_VALIDATION]    Script Date: 13/12/2018 11:48:15 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 -- EXEC [BB_ELA_PATH_VALIDATION] 'MPL_DF_005_016_INT_2'
 -- 
CREATE PROCEDURE [DEV00].[BB_ELA_PATH_VALIDATION] --'MPL_DF_005_063_INT_2'
(	
	@LINE_ELA VARCHAR(50)
)
AS
BEGIN

	DECLARE @LINE_SRC VARCHAR(50),
			@NEXT_ELA VARCHAR(50),
			@ELA_PATH VARCHAR(255),
			@LAST_ELA VARCHAR(50),
			@ORIGLIG_ELA VARCHAR(50)

	SELECT @LINE_SRC = YSRCLONAGR_0 FROM YENTLOAAGR WHERE YLONAGR_0 = @LINE_ELA 
	SET @ORIGLIG_ELA = @LINE_ELA

	-- SOURCE LOAN AGREEMENT MUST BE POPULATED
	IF @LINE_SRC <> ''
	BEGIN

		WHILE (SELECT YSRCLONAGR_0  FROM YENTLOAAGR WHERE YLONAGR_0 = @LINE_ELA) <> ''
		BEGIN	
				
			IF @ELA_PATH <> ''
			BEGIN
				SET @ELA_PATH = CONCAT(@ELA_PATH,',',@LINE_ELA)
			END
			ELSE
			BEGIN
				SET @ELA_PATH = @LINE_ELA
			END
					
			SELECT @NEXT_ELA = YSRCLONAGR_0  FROM YENTLOAAGR WHERE YLONAGR_0 = @LINE_ELA

			IF @NEXT_ELA = '' OR @NEXT_ELA IS NULL
			BEGIN
				SET @LAST_ELA = @LINE_ELA
			END
			ELSE
			BEGIN
				SET @LINE_ELA = @NEXT_ELA	
			END			
			
		END

		SET @ELA_PATH = CONCAT(@ELA_PATH,',',@LINE_ELA)
		IF (SELECT COUNT(*) FROM YICELA WHERE YELASTR_0 = @ORIGLIG_ELA) = 0
		BEGIN	
			IF @LAST_ELA = '' OR @LAST_ELA IS NULL
			BEGIN
				SET @LAST_ELA = @LINE_ELA
			END	
			INSERT INTO YICELA ([UPDTICK_0],[YELASTR_0],[YELAEND_0],[YELAPATH_0],[CREDATTIM_0],[UPDDATTIM_0],[CREUSR_0],[UPDUSR_0],[AUUID_0])
			VALUES (1,@ORIGLIG_ELA,@LAST_ELA,@ELA_PATH, GETDATE(), GETDATE(),'SQL','SQL',NEWID())			
		END
		ELSE
		BEGIN
			UPDATE YICELA
			SET YELAPATH_0 = @ELA_PATH, YELAEND_0 = @NEXT_ELA
			WHERE YELASTR_0 = @ORIGLIG_ELA
		END	
	END
	ELSE
		BEGIN
			IF (SELECT COUNT(*)  FROM YICELA WHERE YELASTR_0 = @ORIGLIG_ELA) = 0
			BEGIN
				INSERT INTO YICELA ([UPDTICK_0],[YELASTR_0],[YELAEND_0],[YELAPATH_0],[CREDATTIM_0],[UPDDATTIM_0],[CREUSR_0],[UPDUSR_0],[AUUID_0])
				VALUES (1,@ORIGLIG_ELA,@ORIGLIG_ELA,@ORIGLIG_ELA, GETDATE(), GETDATE(),'SQL','SQL',NEWID())
			END
			ELSE
			BEGIN
				UPDATE YICELA
				SET YELAPATH_0 = @LINE_ELA, YELAEND_0 =  @LINE_ELA 
				WHERE YELASTR_0 = @ORIGLIG_ELA
			END	
		END
END
GO
/****** Object:  StoredProcedure [DEV00].[BB_ENTRY_VALIDATIONS]    Script Date: 13/12/2018 11:48:15 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 -- EXEC [BB_ENTRY_VALIDATIONS] 'BB20181100004'
 -- 
CREATE PROCEDURE [DEV00].[BB_ENTRY_VALIDATIONS] 
(	
	@YBATNBR VARCHAR(25)
)
AS
BEGIN

		DECLARE @TRANSNBR INT,
				@JNLCOUNT INT,
				@ENTCOUNT INT
		 
		DECLARE TRANS_VAL CURSOR FOR     
		SELECT DISTINCT YTRANSNBR_0 FROM YBBDETAILTEM WHERE YBATNBR_0 = @YBATNBR
  
		OPEN TRANS_VAL    
  
		FETCH NEXT FROM TRANS_VAL     
		INTO @TRANSNBR    
  
		WHILE @@FETCH_STATUS = 0    
		BEGIN
			-- ENTRY TYPE
			SELECT @ENTCOUNT = COUNT(DISTINCT YENTTYP_0)
			FROM YBBDETAILTEM
			WHERE YTRANSNBR_0 = @TRANSNBR and YBATNBR_0 = @YBATNBR
			-- JOURNAL TYPE
			SELECT @JNLCOUNT = COUNT(DISTINCT YJOU_0)
			FROM YBBDETAILTEM 
			WHERE YTRANSNBR_0 = @TRANSNBR and YBATNBR_0 = @YBATNBR
			-- VALIDATION RULE = ALL ENTRIES AND JOURNALS WITHING A TRANSACTION SHOULD BE THE SAME
			IF @ENTCOUNT > 1 AND @JNLCOUNT > 1
			BEGIN
				UPDATE YBBDETAILTEM
				SET YRESVAL_0 = 'ENTVAL_ERR'
				WHERE YTRANSNBR_0 = @TRANSNBR
			END

			FETCH NEXT FROM TRANS_VAL     
			INTO @TRANSNBR   
   
		END     
		CLOSE TRANS_VAL;    
		DEALLOCATE TRANS_VAL;  


END

GO
/****** Object:  StoredProcedure [DEV00].[BB_IE_TRANSACTION_VALIDATION]    Script Date: 13/12/2018 11:48:15 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 -- EXEC [BB_SITE_VALIDATION] 'BB20181100085'
 -- 
CREATE PROCEDURE [DEV00].[BB_IE_TRANSACTION_VALIDATION] --'BB20181100085'
(	
	@YBATNBR VARCHAR(25)	
)
AS
BEGIN
	DECLARE @BATTYP INT,
		    @MINTRANSNBR INT,
			@MAXTRANSNBR INT,
			@MAXFCYCOUNT INT,
			@ELACOUNT    INT,
			@FCYCOUNT	 INT,
			@ELAFCY1	 VARCHAR(10),
			@ELAFCY2	 VARCHAR(10),
			@ELAAGR1	 VARCHAR(50),
			@ELAAGR2	 VARCHAR(50),
			@ELASHTPTH	 VARCHAR(250),
			@PROVIDER1	 VARCHAR(10),
			@PROVIDER2	 VARCHAR(10)			

	SELECT @MAXTRANSNBR = MAX(YTRANSNBR_0) FROM YBBDETAILTEM WHERE YBATNBR_0 = @YBATNBR
	SELECT @MINTRANSNBR = MIN(YTRANSNBR_0) FROM YBBDETAILTEM WHERE YBATNBR_0 = @YBATNBR
	
	WHILE @MINTRANSNBR  <= @MAXTRANSNBR
	BEGIN
		SELECT @BATTYP = YBATTYP_0 from YBBDETAILTEM Where YTRANSNBR_0 = @MINTRANSNBR AND YBATNBR_0 = @YBATNBR	
		IF @BATTYP = 1
		BEGIN
			-- CHECK DISTINCT SITE FOR SAME ELA 
			SELECT @FCYCOUNT = COUNT(DISTINCT(YFCY_0)) FROM YBBDETAILTEM WHERE YTRANSNBR_0 = @MINTRANSNBR AND YBATNBR_0 = @YBATNBR 
			SELECT @ELACOUNT = COUNT(DISTINCT(YELA_0)) FROM YBBDETAILTEM WHERE YTRANSNBR_0 = @MINTRANSNBR AND YBATNBR_0 = @YBATNBR and YELA_0 <> ''

			IF @ELACOUNT = 2 AND @FCYCOUNT = 2
			BEGIN
				SELECT distinct top 1 @ELAFCY1 = YFCY_0 FROM YBBDETAILTEM WHERE YTRANSNBR_0 = @MINTRANSNBR AND YBATNBR_0 = @YBATNBR
				SELECT distinct top 1 @ELAAGR1 = YELA_0 FROM YBBDETAILTEM WHERE YTRANSNBR_0 = @MINTRANSNBR AND YBATNBR_0 = @YBATNBR and YFCY_0 = @ELAFCY1

				SELECT distinct top 1 @ELAFCY2 = YFCY_0 FROM YBBDETAILTEM WHERE YTRANSNBR_0 = @MINTRANSNBR AND YBATNBR_0 = @YBATNBR AND YFCY_0 <> @ELAFCY1
				SELECT distinct top 1 @ELAAGR2 = YELA_0 FROM YBBDETAILTEM WHERE YTRANSNBR_0 = @MINTRANSNBR AND YBATNBR_0 = @YBATNBR AND YFCY_0 = @ELAFCY2

				-- Update From and To Site in TEMP Table to read to simulation lines
				Update YBBDETAILTEM
				SET YFRMFCY_0 = @ELAFCY1, YTOFCY_0 = @ELAFCY2
				WHERE YTRANSNBR_0 = @MINTRANSNBR AND YBATNBR_0 = @YBATNBR
				
			IF (@ELAAGR1 <> '' AND @ELAAGR2 <> '')
			BEGIN

				EXEC [DEV00].[BB_ELA_PATH_VALIDATION] @ELAAGR1
				EXEC [DEV00].[BB_ELA_PATH_VALIDATION] @ELAAGR2

				SELECT @PROVIDER1 = YFCYPRO_0 FROM YENTLOAAGR WHERE YLONAGR_0 = (SELECT YELAEND_0 FROM YICELA WHERE YELASTR_0 = @ELAAGR1)
				SELECT @PROVIDER2 = YFCYPRO_0 FROM YENTLOAAGR WHERE YLONAGR_0 = (SELECT YELAEND_0 FROM YICELA WHERE YELASTR_0 = @ELAAGR2)
				
				--IF @PROVIDER1 = @ELAFCY1 AND @PROVIDER2 = @ELAFCY2
				IF @PROVIDER1 = @PROVIDER2
				BEGIN
					select @ELASHTPTH = YELAPATH_0 from YICELA WHERE YELASTR_0 = @ELAAGR1
									
					UPDATE YBBDETAILTEM
					SET YRESVAL_0 = @ELAAGR1
					WHERE YTRANSNBR_0 = @MINTRANSNBR AND YBATNBR_0 = @YBATNBR AND YFCY_0 = @ELAFCY1
														
					-- Get ELA Paths to expand FCY2
					SET @ELASHTPTH = ''				
					select @ELASHTPTH = YELAPATH_0 from YICELA WHERE YELASTR_0 = @ELAAGR2

					UPDATE YBBDETAILTEM
					SET YRESVAL_0 = @ELASHTPTH
					WHERE YTRANSNBR_0 = @MINTRANSNBR AND YBATNBR_0 = @YBATNBR AND YFCY_0 = @ELAFCY2
				END
				ELSE
				BEGIN
					UPDATE YBBDETAILTEM
					SET YRESVAL_0 = 'PROVIDER1'
					WHERE YTRANSNBR_0 = @MINTRANSNBR AND YBATNBR_0 = @YBATNBR AND YFCY_0 = @ELAFCY1
					UPDATE YBBDETAILTEM
					SET YRESVAL_0 = 'PROVIDER2'
					WHERE YTRANSNBR_0 = @MINTRANSNBR AND YBATNBR_0 = @YBATNBR AND YFCY_0 = @ELAFCY2	
				END
			END
			ELSE
			BEGIN
				-- ELA SITE MISMATCH
				UPDATE YBBDETAILTEM
				SET YRESVAL_0 = 'ELAMIS'
				WHERE YTRANSNBR_0 = @MINTRANSNBR AND YBATNBR_0 = @YBATNBR AND YFCY_0 = @ELAFCY1
				UPDATE YBBDETAILTEM
				SET YRESVAL_0 = 'ELAMIS'
				WHERE YTRANSNBR_0 = @MINTRANSNBR AND YBATNBR_0 = @YBATNBR AND YFCY_0 = @ELAFCY2				
			END
		END
		END
		set @MINTRANSNBR += 1
	END
END
GO
/****** Object:  StoredProcedure [DEV00].[BB_SITE_VALIDATION]    Script Date: 13/12/2018 11:48:15 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 -- EXEC [BB_SITE_VALIDATION] 'BB181200021'
 -- 
CREATE PROCEDURE [DEV00].[BB_SITE_VALIDATION] 
(	
	@YBATNBR VARCHAR(25)
)
AS
BEGIN

	DECLARE @BATTYP	 INT,
			@SITE1		 VARCHAR(5),
			@SITE2		 VARCHAR(5),
			@MINTRANSNBR INT,
			@MAXTRANSNBR INT,
			@MAXFCYCOUNT INT


	SELECT @MAXTRANSNBR = MAX(YTRANSNBR_0) FROM YBBDETAILTEM WHERE YBATNBR_0 = @YBATNBR
	SELECT @MINTRANSNBR = MIN(YTRANSNBR_0) FROM YBBDETAILTEM WHERE YBATNBR_0 = @YBATNBR

	WHILE @MINTRANSNBR <= @MAXTRANSNBR
	BEGIN
		-- CHECK THE TRANSACTION NUMBER BATCH TYPE
		SELECT @BATTYP = YBATTYP_0
		FROM YBBDETAILTEM
		WHERE YBATNBR_0 = @YBATNBR AND YTRANSNBR_0 = @MINTRANSNBR 

		-- COUNT NUMBER OF SITES PER TRANSACTION NUMBER
		IF @BATTYP = 1 -- IE
		BEGIN
			SELECT @MAXFCYCOUNT = COUNT(DISTINCT YFCY_0)
			FROM YBBDETAILTEM
			WHERE YBATNBR_0 = @YBATNBR AND YTRANSNBR_0 = @MINTRANSNBR AND YBATTYP_0 = @BATTYP
			IF @MAXFCYCOUNT <> 2 
			BEGIN
				UPDATE YBBDETAILTEM 
				SET YRESVAL_0 = 'FCY1'
				WHERE YBATNBR_0 = @YBATNBR AND YTRANSNBR_0 = @MINTRANSNBR
			END
			ELSE
			BEGIN
				-- Update From and To Site
				SELECT @SITE1 = YFCY_0 FROM YBBDETAILTEM WHERE YTRANSNBR_0 = @MINTRANSNBR AND YBATNBR_0 = @YBATNBR
				AND YFCY_0 = (SELECT TOP 1 YFCY_0 FROM YBBDETAILTEM WHERE YTRANSNBR_0 = @MINTRANSNBR AND YBATNBR_0 = @YBATNBR)
				SELECT @SITE2 = YFCY_0 FROM YBBDETAILTEM WHERE YTRANSNBR_0 = @MINTRANSNBR AND YBATNBR_0 = @YBATNBR
				AND YFCY_0 <> @SITE1

				UPDATE YBBDETAILTEM 
				SET YFRMFCY_0 = @SITE1, YTOFCY_0 = @SITE2
				WHERE YBATNBR_0 = @YBATNBR AND YTRANSNBR_0 = @MINTRANSNBR
			END
		END
		IF @BATTYP = 2 -- Journal
		BEGIN
			SELECT @MAXFCYCOUNT = COUNT(DISTINCT YFCY_0)
			FROM YBBDETAILTEM
			WHERE YBATNBR_0 = @YBATNBR AND YTRANSNBR_0 = @MINTRANSNBR AND YBATTYP_0 = @BATTYP
			IF @MAXFCYCOUNT <> 1 
			BEGIN
				UPDATE YBBDETAILTEM 
				SET YRESVAL_0 = 'FCY2'
				WHERE YBATNBR_0 = @YBATNBR AND YTRANSNBR_0 = @MINTRANSNBR
			END
		END
		IF @BATTYP = 3 -- Cash
		BEGIN
			SELECT @MAXFCYCOUNT = COUNT(DISTINCT YFCY_0)
			FROM YBBDETAILTEM
			WHERE YBATNBR_0 = @YBATNBR AND YTRANSNBR_0 = @MINTRANSNBR AND YBATTYP_0 = @BATTYP
			IF @MAXFCYCOUNT <> 1 
			BEGIN
				UPDATE YBBDETAILTEM 
				SET YRESVAL_0 = 'FCY3'
				WHERE YBATNBR_0 = @YBATNBR AND YTRANSNBR_0 = @MINTRANSNBR
			END
		END
		SET @MINTRANSNBR += 1
	END	

END

GO
