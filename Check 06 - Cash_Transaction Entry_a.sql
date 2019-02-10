USE [x3dev0]
GO
/****** Object:  StoredProcedure [DEV00].[BB_CASH_TRANSACTION_VALIDATION]    Script Date: 4/02/2019 4:10:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [DEV00].[BB_CASH_TRANSACTION_VALIDATION] 
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
		SELECT @BATTYP = YBATTYP_0 FROM YBBDETAILTEM WHERE YTRANSNBR_0 = @MINTRANSNBR AND YBATNBR_0 = @YBATNBR
		IF @BATTYP = 2
		BEGIN
			-- DISTINCT BANK A/C = 2
			SELECT @BANKCOUNT = COUNT(DISTINCT(YBAN_0)) FROM YBBDETAILTEM WHERE YTRANSNBR_0 = @MINTRANSNBR AND YBATNBR_0 = @YBATNBR AND YBATTYP_0 = @BATTYP AND YBAN_0 <> ''
			IF (@BANKCOUNT = 1) --OR (@BANKCOUNT = 2) #DFCX1-344
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
				IF @BANKCOUNT > 2
				BEGIN
				UPDATE YBBDETAILTEM
				SET YRESVAL_0 = 'BCNT1' -- CANNOT HAVE MORE THAN 2 DISTINCT BANK ACCOUNTS
				WHERE YTRANSNBR_0 = @MINTRANSNBR AND YBATNBR_0 = @YBATNBR
				END
				IF @BANKCOUNT = 0 
				BEGIN
				UPDATE YBBDETAILTEM
				SET YRESVAL_0 = 'BCNT2' -- MUST HAVE ATLEAST 1 BANK
				WHERE YTRANSNBR_0 = @MINTRANSNBR AND YBATNBR_0 = @YBATNBR
				END
			END
		END
		SET @MINTRANSNBR += 1
	END	
END



