USE [x3dev0]
GO
/****** Object:  StoredProcedure [DEV00].[SearchELA]    Script Date: 21/11/2018 9:32:06 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER Proc [DEV00].[SearchELA] @input1 int,@Input2 int  , @TreeHeader varchar(50) ='MPL'  
As  
--drop table #X  
Select SeqNo,ELA_ID_CHAINS,Last_ELA_ID,FIRST_PROV_CPY,Head,PathLevel into #X  
from [DEV00].[vZLEVICLA_NAVIGATIONv5]   where Head = @TreeHeader
order by SeqNo  
  
-- Select * from #X  Select * from [DEV00].[vZLEVICLA_NAVIGATIONv5]  
-- drop table #Path  
  
 If (@input1 =-99 and @Input2 <> -99) or ( @input1 <> -99  and @Input2 =-99)  
 Begin  
   Select *  
   into #OneWayPath  
   From  
   (   
		Select SeqNo,ELA_ID_CHAINS,FIRST_PROV_CPY,Last_ELA_ID,value as Detected_ELA_ID,  
		row_number() over (partition by SeqNo, SeqNo order by ELA_ID_CHAINS) Ranking,PathLevel  
		from #X   
		cross apply  STRING_SPLIT(ELA_ID_CHAINS,',')  
		where Last_ELA_ID in (@input1,@Input2)   
   ) X  
   where X.Ranking <> 1  
    
  Select * from #OneWayPath  
  Drop table #X  
  Drop table #OneWayPath  
  Return  
 End  
  
 Select SeqNo,ELA_ID_CHAINS,FIRST_PROV_CPY,Last_ELA_ID,value as Detected_ELA_ID, PathLevel, 
 row_number() over (partition by SeqNo, SeqNo order by ELA_ID_CHAINS) Ranking  
 into #Path  
 from #X   
 cross apply  STRING_SPLIT(ELA_ID_CHAINS,',')  
    where Last_ELA_ID in (@input1,@Input2)  
    and  FIRST_PROV_CPY  = ( Select  top 1 FIRST_PROV_CPY from  #X where Last_ELA_ID in  (@input1,@Input2) 
								group by FIRST_PROV_CPY having count(*) > 1 
							    order by Sum(PathLevel) asc
 )  
  
--Select * from #Path  
  
 DECLARE @Flag char(1),@Level int,@ActualLevel int  
 SET @Flag = 'Y';  
 Set @Level = 1  
  
 WHILE @Flag = 'Y'  
 BEGIN  
  
  Select @Flag = Case When count(Detected_ELA_ID) = 2  and ( max(Detected_ELA_ID) = min(Detected_ELA_ID)) Then 'Y' Else 'N' End-- Flag  
  from #Path where Ranking = @Level  
  
  Set @ActualLevel = @Level  
  --Select 'Actual Level : ' + cast(@ActualLevel as varchar(max))  
  If @Flag  <> 'Y'   
    Break  
  Else  
  SET @Level = @Level + 1;  
       
 END  
  
 --Select 'Intersection met at: ' + Cast( @ActualLevel as varchar(max)) as Debug  
  
 Select * from #Path where Ranking >= @ActualLevel   --(1,6) --(7,6) --(6,12)  
 Drop table #X  
 Drop table #Path