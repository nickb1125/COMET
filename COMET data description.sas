/*******************************************************************\
*  PROGRAM:      COMET data description
*  PROJECT:      AFT25: COMET                                      *
*  PROGRAMMER:   Christel Rushing                                  *
*  DATE:         12 July 2021                                      * 
*  DESCRIPTION:  summarizing data and switching             	   *
*   NOTES:     data quality is the priority                        * 
\*******************************************************************/;


libname cometdta 'H:\DCI\Breast\COMET\data';
%let cutdate='14Jun2021'd;

comment CRF: Registration;
/** .N means the parent question was answered "No" so the follow-up should be blank. .M means the parent questioned wasn't answered and that is why the follow-up is blank. **/
proc sql;
	create table elig as
	select subject, site, eligible, ELIGIBLE_STD as eligible_numeric label="Numeric Eligibility (1=Yes, 2=No)", NEWDCISDX 
		label="New diagnosis of DCIS without invasive cancer (Unilateral, bilateral, unifocal, multifocal, or multicentric DCIS or atypia verging on DCIS or DCIS + LCIS will be 
		eligible, provided that each meets eligibility criteria)", datepart(LASTMAMMDT) as dt_lastmammo format=date9. label="Date of last mammogram, should be <=120 days from
		registration date or <=60 days from registration if patient has had prior surgery", datepart(CONFIRMDCISDT) as dt_dcisconfm format=date9. 
		label="Date of confirmation of DCIS, atypia verging on DCIS, DCIS+LCIS (last diagnostic core biopsy or surgical excision—must be <=120 days from registration date)",
		CONIRMPATH label="Is there confirmation that pathology was reviewed by 2 pathologists?", ICPARSIGN label="Has patient signed an informed consent to participate in this study?",
		ifn(missing(ICPARSIGN),.M, ifn(ICPARSIGN="No",.N,datepart(ICPARSIGNDT))) as dt_ic_this format=date9. label="Date informed consent for this study was signed",
		ICFUTSIGN label="Has patient signed an informed consent to be contacted for future studies?",
		ifn(missing(ICFUTSIGN),.M, ifn(ICFUTSIGN="No",.N,datepart(ICFUTSIGNDT))) as dt_ic_future format=date9. label="Date informed consent for future contact was signed"
	from cometdta.registration
	order by subject asc;
quit;

comment CRF: Randomization;
proc sql;
	create table randomization as
	select subject,recordid, site, REGIME_NAME,REGIME_NAME_STD as REGIME_numeric label="Numeric treatment code", REGIME_NAME_DRV label="Treatment Arm (derived field in database)",  
		datepart(RANDOMIZED_AT) as dt_randomized format=date9.,DCISAGE, DCISAGE_STD as dcisage_numeric,MICROCALC,MICROCALC_STD as microcalc_numeric, GRADE, GRADE_STD as grade_numeric 
	from cometdta.randomize
	where datepart(RANDOMIZED_AT) le &cutdate.	
	order by subject asc, recordid asc;
quit;
/** recordid was included just in case subjects were in the data twice**/
/** patients are not informed of arm assignment until after baseline survey packet. so check on arms and data completeness for baseline and then after**/


comment CRF: Demographics;
proc sql;
	create table demographics_a as
	select subject, recordid, site, datepart(PER_BIR_DT) as dt_birth format=date9. label='Date of birth',ifc(race="Other, specify",propcase(RACESP),propcase(race)) as race_comb 
		label="Race with any written in 'Other' included", race label='Original race variable',  RACE_STD as race_numeric label='Numeric codes for original race variable',
		racesp,ethnicity,ETHNICITY_STD as ETHNICITY_numeric	label='Numeric codes for ethnicity variable',INITIALS,datepart(NOW) as dt_now format=date9. 
		label='a date variable from the demographic data named NOW'
	from cometdta.raceeth
	order by subject asc, recordid asc;
quit; /**Patients were given the option to choose just one race. Some biracial pts chose "other" and then wrote in the two. 
		I wonder how many other biracial patients are in the dataset mispecified because they were told to choose just one and followed that instruction...**/


comment CRF: On-Study;
/** .N means the parent question was answered "No" so the follow-up should be blank. .M means the parent questioned wasn't answered and that is why the follow-up is blank. **/
proc sql;
	create table demographics_b as
	select subject, recordid,height label='height in cm',weight label="weight in kg", weight/(height/100)**2 as cnr_bmi label="BMI kg/m^2", ECOGPSBSL_STD label='ECOG performance status', 
		DCISLAT, DCISLAT_STD as dcislat_numeric,HPTUSEYN as hrt_ever label="hormone replacement therapy use, ever",
		ifn(missing(HPTUSEYN),.M, ifn(HPTUSEYN="No",.N,datepart(HPTLASTDT))) as dt_last_hpt format=date9. label="date of last hormone therapy use",  
		ifc(missing(HPTUSEYN),' ', ifc(HPTUSEYN="No",'No - Never had HRT',HTUSECUR)) as hrt_current label="hormone replacement therapy, currently" ,
		PREGFULLTERM, PREGFULLTERM_STD as PREGFULLTERM_numeric,
		ifn(missing(PREGFULLTERM) or strip(PREGFULLTERM)="Unknown",.M, ifn(PREGFULLTERM="No",.N,AGEATFRSTPREGFULLTERM)) as first_preg_age label="age at first full term pregnancy", 
		ifn(missing(PREGFULLTERM) or strip(PREGFULLTERM)="Unknown",.M, ifn(PREGFULLTERM="No",0,numdaughter)) as daughter_count label="number of daughters born", 
		ifn(missing(PREGFULLTERM) or strip(PREGFULLTERM)="Unknown",.M, ifn(PREGFULLTERM="No",0,numson)) as son_count label="number of sons born", 
		ifn(missing(PREGFULLTERM) or strip(PREGFULLTERM)="Unknown",.M, ifn(PREGFULLTERM="No",0,numdaughter))+ 
		ifn(missing(PREGFULLTERM) or strip(PREGFULLTERM)="Unknown",.M, ifn(PREGFULLTERM="No",0,numson))as cnr_children_born label="number of children born",	
		PREVDCISSURG label="Has the patient had previous surgery for DCIS (must be <=120 days from registration date)?", 
		PREVDCISSURG_STD as PREVDCISSURG_numeric label="Numeric code for previous DCIS surgery indicator (1=Yes, 2=No)",
		CANDFORLUMPECTMY label="Does the surgeon feel the patient was a candidate for lumpectomy at baseline assessment?",CANDFORLUMPECTMY_STD as CANDFORLUMPECTMY_numeric,
		MENOSTATRAND label="Menopausal status at time of randomization",MENOSTATRAND_STD as MENOSTATRAND_numeric 
	from cometdta.onstudy
	order by subject asc,recordid asc;
quit; /** noticed subject 250016007 is missing everything in this table. should run a check on how many patients have no data in each table **/

proc freq data=demographics_b;
	tables _character_ / missing;
run;


comment CRF: On-Study: DCIS Disease Status (Left Breast) then (Right Breast);
/*** not needed for primary analysis, not as high as priority, but still need to know whether people are filling it out in case we need it later for descriptives in the manuscript**/
/** .N means the parent question was answered "No" so the follow-up should be blank. .M means the parent questioned wasn't answered and that is why the follow-up is blank. **/
proc sql;
	create table dcisleft_baseline as
	select subject,recordid,cycle,NUCGRADE as L_NUCGRADE label="Nuclear grade for DCIS in left breast (Atypia verging on DCIS should be coded as Grade 1)",
		NUCGRADE_STD as L_NUCGRADE_numeric, ATYPIAYN as L_ATYPIAYN label="Atypia verging on DCIS in left breast",ATYPIAYN_STD as L_ATYPIAYN_numeric,
		ER as L_ER label="ER receptor status in left breast (positive if >= 10%)",ER_STD as L_ER_numeric,
		ifn(missing(ER) or strip(ER)="Unknown",.M,ERSTAIN) as L_ERSTAIN label="ER percent staining for left breast",
		ERSTAINUNK as L_ERSTAINUNK label="numeric indicator for unknown ER staining for left breast", 
		ERSTAININTENS as L_ERSTAININTENS label="Highest Intensity of staining, ER for left breast", ERSTAININTENS_STD as L_ERSTAININTENS_numeric,
		PGR as L_PGR label="PgR receptor status in left breast (positive if >= 10%)",
		PGR_STD as L_PGR_numeric, ifn(missing(PGR) or strip(PGR)="Unknown",.M,PGRSTAIN) as L_PGRSTAIN label="PgR percent staining for left breast",
		PGRSTAINUNK as L_PGRSTAINUNK label="numeric indicator for unknown PgR staining for left breast", 
		PGRSTAININTENS as L_PGRSTAININTENS label="Highest Intensity of staining, PgR for left breast",PGRSTAININTENS_STD as L_PGRSTAININTENS_numeric,
		IHCHER2STAT as L_IHCHER2STAT label="IHC HER2-neu Status in left breast",IHCHER2STAT_STD as L_IHCHER2STAT_numeric,
		FISHHER2NEU as L_FISHHER2NEU label="Was HER2-neu FISH performed for left breast?",FISHHER2NEU_STD as L_FISHHER2NEU_numeric,
		ifn(missing(FISHHER2NEU) or strip(FISHHER2NEU)="Unknown",.M, ifn(FISHHER2NEU="No",.N,FISHHER2NEURATIO)) as L_FISHHER2NEURATIO label="HER2-neu FISH ratio in left breast"
	from cometdta.Onstudydcisleft
	order by subject asc, recordid asc;
quit; 
proc sql;
	create table dcisright_baseline as
	select subject,recordid,cycle,NUCGRADE as R_NUCGRADE label="Nuclear grade for DCIS in right breast (Atypia verging on DCIS should be coded as Grade 1)",
		NUCGRADE_STD as R_NUCGRADE_numeric, ATYPIAYN as R_ATYPIAYN label="Atypia verging on DCIS in right breast",ATYPIAYN_STD as R_ATYPIAYN_numeric,
		ER as R_ER label="ER receptor status in right breast (positive if >= 10%)",ER_STD as R_ER_numeric,
		ifn(missing(ER) or strip(ER)="Unknown",.M,ERSTAIN) as R_ERSTAIN label="ER percent staining for right breast",
		ERSTAINUNK as R_ERSTAINUNK label="numeric indicator for unknown ER staining for right breast", 
		ERSTAININTENS as R_ERSTAININTENS label="Highest Intensity of staining, ER for right breast", ERSTAININTENS_STD as R_ERSTAININTENS_numeric,
		PGR as R_PGR label="PgR receptor status in right breast (positive if >= 10%)",
		PGR_STD as R_PGR_numeric, ifn(missing(PGR) or strip(PGR)="Unknown",.M,PGRSTAIN) as R_PGRSTAIN label="PgR percent staining for right breast",
		PGRSTAINUNK as R_PGRSTAINUNK label="numeric indicator for unknown PgR staining for right breast", 
		PGRSTAININTENS as R_PGRSTAININTENS label="Highest Intensity of staining, PgR for right breast",PGRSTAININTENS_STD as R_PGRSTAININTENS_numeric,
		IHCHER2STAT as R_IHCHER2STAT label="IHC HER2-neu Status in right breast",IHCHER2STAT_STD as R_IHCHER2STAT_numeric,
		FISHHER2NEU as R_FISHHER2NEU label="Was HER2-neu FISH performed for right breast?",FISHHER2NEU_STD as R_FISHHER2NEU_numeric,
		ifn(missing(FISHHER2NEU) or strip(FISHHER2NEU)="Unknown",.M, ifn(FISHHER2NEU="No",.N,FISHHER2NEURATIO)) as R_FISHHER2NEURATIO label="HER2-neu FISH ratio in right breast"
	from cometdta.Onstudydcisright
	order by subject asc, recordid asc;
quit; 

comment CRF: Summary of Prior DCIS Surgeries; 
/** .N means the parent question was answered "No" or did not apply so the follow-up should be blank. .M means the parent questioned wasn't answered and that is why the follow-up is blank. **/
proc sql;
	create table priorsurg as
	select subject,recordid,cycle,datepart(SURG_DT) as dt_priorsurg label="Date of surgery prior to registration",SURGLAT as prior_SURGLAT,SURGLAT_STD as prior_SURGLAT_num,
		SURGTYP as prior_surgtyp,SURGTYP_STD as prior_SURGTYP_num,
		ifc(missing(SURGTYP) or strip(SURGTYP)="Unknown","Missing/Unknown Surgery Type",ifc(SURGTYP^="Mastectomy","Non-Mastectomy",SURGBRSTRECON)) 
			as prior_Reconstruction label="If Mastectomy, was breast reconstruction performed as part of this surgery?)",
		ifn(missing(SURGTYP) or strip(SURGTYP)="Unknown",.M,ifn(SURGTYP^="Mastectomy",.N,SURGBRSTRECON_STD)) as prior_Reconstruction_num,
		ifc(missing(SURGTYP) or strip(SURGTYP)="Unknown","Missing/Unknown Surgery Type",ifc(SURGTYP^="Mastectomy","Non-Mastectomy",DZEXTENT)) 
			as prior_extent_disease label="Reasons for choice of Mastectomy - Extent of Disease?)",
		ifn(missing(SURGTYP) or strip(SURGTYP)="Unknown",.M,ifn(SURGTYP^="Mastectomy",.N,DZEXTENT_STD)) as prior_extent_num,
		ifc(missing(SURGTYP) or strip(SURGTYP)="Unknown","Missing/Unknown Surgery Type",ifc(SURGTYP^="Mastectomy","Non-Mastectomy",RADTCONTRAIND)) 
			as prior_rtcontraind label="Reasons for choice of Mastectomy - Contraindication to radiation therapy?)",
		ifn(missing(SURGTYP) or strip(SURGTYP)="Unknown",.M,ifn(SURGTYP^="Mastectomy",.N,RADTCONTRAIND_STD)) as prior_rtcontraind_num,
		ifc(missing(SURGTYP) or strip(SURGTYP)="Unknown","Missing/Unknown Surgery Type",ifc(SURGTYP^="Mastectomy","Non-Mastectomy",PATPREF)) 
			as prior_ptpreference label="Reasons for choice of Mastectomy - Patient Preference?)",
		ifn(missing(SURGTYP) or strip(SURGTYP)="Unknown",.M,ifn(SURGTYP^="Mastectomy",.N,PATPREF_STD)) as prior_ptpreference_num,
		ifc(missing(SURGTYP) or strip(SURGTYP)="Unknown","Missing/Unknown Surgery Type",ifc(SURGTYP^="Mastectomy","Non-Mastectomy",ifc(^missing(RSNOTHER),ifc(RSNOTHER="Yes",RSNOTHERSP,"No 'other' reason"),' '))) 
			as prior_othermxreas label="Reasons for choice of Mastectomy - Other reason?)",
		ifn(missing(SURGTYP) or strip(SURGTYP)="Unknown",.M,ifn(SURGTYP^="Mastectomy",.N,RSNOTHER_STD)) as prior_othermxreas_num,
		ifn(missing(SURGPATHREP),.M,DCISDZEXTENT) as prior_pathrpt_size label="DCIS disease extent in cm from Pathology Report",
		ifc(missing(SURGPATHREP),"Missing Pathology Report",DCISPRESENT) as prior_pathrpt_margins label="DCIS present at the final margin? from Pathology Report",
		ifn(missing(SURGPATHREP),.M,DCISPRESENT_STD) as prior_pathrpt_margins_num,
		ifc(missing(SURGPATHREP),"Missing Pathology Report",DCISWIDTH) as prior_pathrpt_width label="Width of closest margin from Pathology Report",

		ER as prior_ER label="ER status for prior surgery",ER_STD as prior_ER_num, ERSTAIN as prior_ERSTAIN label="for prior surgery, the % staining, ER",
		ERSTAINUNK as prior_ERSTAINUNK, ERSTAININTENS as prior_ERSTAININTENS label="Highest intensity of ER staining for prior surgery",ERSTAININTENS_STD as prior_ERSTAININTENS_num,
		PGR as prior_PGR label="PgR status for prior surgery", PGR_STD as prior_PGR_num,PGRSTAIN as prior_PGRSTAIN label="for prior surgery, the % staining, PgR",
		PGRSTAINUNK as prior_PGRSTAINUNK, PGRSTAININTENS as prior_PGRSTAININTENS label="Highest intensity of PgR staining for prior surgery",
		PGRSTAININTENS_STD as prior_PGRSTAININTENS_num,IHCHER2STAT as prior_IHCHER2STAT label="IHC HER2-neu Status for prior surgery",IHCHER2STAT_STD as prior_IHCHER2STAT_num,
		FISHHER2NEU as prior_FISHHER2NEU label="Was HER2-neu FISH performed for prior surgery?",FISHHER2NEU_STD as prior_FISHHER2NEU_num,
		ifn(missing(FISHHER2NEU) or strip(FISHHER2NEU)="Unknown",.M, ifn(FISHHER2NEU="No",.N,FISHHER2NEURATIO)) as prior_FISHHER2NEURATIO label="HER2-neu FISH ratio for prior surgery",

		SLNDYN as prior_SLNDYN label="Was sentinel node sampling performed (for prior surgery)?", SLNDYN_STD as prior_SLNDYN_num,
		ifn(missing(SLNDYN),.M, ifn(SLNDYN="No",.N,datepart(SLNDDT))) as dt_slnd format=date9. label="Date of sentinel node biopsy (for prior surgery)", 
		ifn(missing(SLNDYN),.M, ifn(SLNDYN="No",.N,SLNDTOTALN)) as prior_slndtotaln  label="Total number of nodes removed during SLND (for prior surgery)", 
		ifn(missing(SLNDYN),.M, ifn(SLNDYN="No",.N,SLNDPOSN)) as prior_SLNDPOSN label="Number of positive nodes removed during SLND (for prior surgery)", 
		ALNDYN as prior_ALNDYN label="Was axillary lymph node dissection (ALND) performed (for prior surgery)?", ALNDYN_STD as prior_ALNDYN_num,
		ifn(missing(ALNDYN),.M, ifn(ALNDYN="No",.N,datepart(ALNDDT))) as dt_alnd format=date9. label="Date of axillary node biopsy (for prior surgery)", 
		ifn(missing(ALNDYN),.M, ifn(ALNDYN="No",.N,ALNDAXILN)) as prior_ALNDAXILN  label="Number of axillary lymph nodes in ALND (for prior surgery)", 
		ifn(missing(ALNDYN),.M, ifn(ALNDYN="No",.N,ALNDPOSN)) as prior_ALNDPOSN label="Number of positive lymph nodes in ALND (for prior surgery)", 
		ADDSURGREQ as prior_ADDSURGREQ label="Were additional surgeries required to obtain clear margins (for prior surgery)?", ADDSURGREQ_STD as prior_ADDSURGREQ_num,
		ifn(missing(ADDSURGREQ),.M, ifn(ADDSURGREQ="No",.N,NUMADDSURGREQ)) as prior_NUMADDSURGREQ  label="Number of additional surgeries required to obtain clear margins (for prior surgery)", 
		DCISMARG as prior_DCISMARG label="DCIS margins from prior surgery", DCISMARG_STD as prior_DCISMARG_num

	from cometdta.Prisurgsummary
	order by subject asc, recordid asc;
quit;
proc freq data=priorsurg;
	tables _character_ / missing;
run;

comment CRF: Change In Treatment/Management Approach (Including Allocation Refusal); 
/** .N means the parent question was answered "No" or did not apply so the follow-up should be blank. .M means the parent questioned wasn't answered and that is why the follow-up is blank. **/
proc sql;
	create table crossover0 as
	select subject,recordid,cycle,
		SURGOPT label="Did the patient opt to proceed with surgery in the absence of invasive progression?", SURGOPT_STD as SURGOPT_numeric,
		ifn(missing(SURGOPT),.M, ifn(SURGOPT="No",.N,datepart(DCLNAMDT))) as dt_surgopt format=date9. label="Date patient declined monitoring in favor of surgery",
		ifc(SURGOPT="No",'NA - did not opt for surgery',PATANXT) as surgopt_PATANXT  label="Opted to proceed with surgery instead of AM because of Patient Anxiety?", 
		ifn(missing(SURGOPT),.M, ifn(SURGOPT="No",.N,PATANXT_STD)) as surgopt_PATANXT_num, 
		ifc(SURGOPT="No",'NA - did not opt for surgery',DCISCHNGE) as surgopt_DCISCHNGE  label="Opted to proceed with surgery instead of AM because of Change in DCIS?", 
		ifn(missing(SURGOPT),.M, ifn(SURGOPT="No",.N,DCISCHNGE_STD)) as surgopt_DCISCHNGE_num, 
		ifc(SURGOPT="No",'NA - did not opt for surgery',DCISNEW) as surgopt_DCISNEW  label="Opted to proceed with surgery instead of AM because of New DCIS?", 
		ifn(missing(SURGOPT),.M, ifn(SURGOPT="No",.N,DCISNEW_STD)) as surgopt_DCISNEW_num, 
		ifc(SURGOPT="No",'NA - did not opt for surgery',SURGOPTPROVRECM) as SURGOPT_PROVRECM  label="Opted to proceed with surgery instead of AM because of Provider Recommendation?", 
		ifn(missing(SURGOPT),.M, ifn(SURGOPT="No",.N,SURGOPTPROVRECM_STD)) as surgopt_PROVRECM_num, 
		ifc(SURGOPT="No",'NA - did not opt for surgery',SURGOPTPATPREF) as SURGOPT_PATPREF  label="Opted to proceed with surgery instead of AM because of Patient Preference?", 
		ifn(missing(SURGOPT),.M, ifn(SURGOPT="No",.N,SURGOPTPATPREF_STD)) as surgopt_PATPREF_num, 
		ifc(SURGOPT="No",'NA - did not opt for surgery',ifc(SURGOPTRSNOTH="No","No other reason",SURGOPTRSNOTHSP)) as SURGOPT_RSNOTH  label="Opted to proceed with surgery instead of AM for another reason?", 
		ifn(missing(SURGOPT),.M, ifn(SURGOPT="No",.N,SURGOPTRSNOTH_STD)) as SURGOPT_RSNOTH_num, 

		DECLNALLOCARM as AMOPT label="Did the patient decline allocation for the Surgery arm?", DECLNALLOCARM_STD as AMOPT_numeric,
		ifn(missing(DECLNALLOCARM),.M, ifn(DECLNALLOCARM="No",.N,datepart(DCLNTXRECMDT))) as dt_AMOPT format=date9. 
			label="Date patient declined treatment recommendations (surgery) in favor of monitoring",
		ifc(DECLNALLOCARM="No",'NA - did not opt for AM',SURGPATANXT) as AMOPT_PATANXT  label="Opted to proceed with AM instead of surgery because of Patient Anxiety about surgery?", 
		ifn(missing(DECLNALLOCARM),.M, ifn(DECLNALLOCARM="No",.N,SURGPATANXT_STD)) as AMOPT_PATANXT_num, 
		ifc(DECLNALLOCARM="No",'NA - did not opt for AM',DCLNPROVRECM) as AMOPT_PROVRECM  label="Opted to proceed with AM instead of surgery because of Provider Recommendation?", 
		ifn(missing(DECLNALLOCARM),.M, ifn(DECLNALLOCARM="No",.N,DCLNPROVRECM_STD)) as AMOPT_PROVRECM_num, 
		ifc(DECLNALLOCARM="No",'NA - did not opt for AM',SURGPOORCAND) as AMOPT_SURGPOORCAND  label="Opted to proceed with AM instead of surgery because of Poor candidate for surgery?", 
		ifn(missing(DECLNALLOCARM),.M, ifn(DECLNALLOCARM="No",.N,SURGPOORCAND_STD)) as AMOPT_SURGPOORCAND_num, 		
		ifc(DECLNALLOCARM="No",'NA - did not opt for AM',DECLNPATPREF) as AMOPT_PATPREF  label="Opted to proceed with AM instead of surgery because of Patient Preference?", 
		ifn(missing(DECLNALLOCARM),.M, ifn(DECLNALLOCARM="No",.N,DECLNPATPREF_STD)) as AMOPT_PATPREF_num, 
		ifc(DECLNALLOCARM="No",'NA - did not opt for AM',ifc(DECLNRSNOTH="No","No other reason",DECLNRSNOTHSP)) as AMOPT_RSNOTH  label="Opted to proceed with AM instead of surgery for another reason?", 
		ifn(missing(DECLNALLOCARM),.M, ifn(DECLNALLOCARM="No",.N,DECLNRSNOTH_STD)) as AMOPT_RSNOTH_num

	from cometdta.crossover
	order by subject asc, recordid asc;
quit;
data crossover1;
	set crossover0;
	length switch_nature $30 switch_PATANXT $3 switch_provrecm $3 switch_PATPREF $3 switch_RSNOTH $500;
	by subject recordid;
	if surgopt="Yes" then switch_nature="Active Monitoring-->Surgery";
	else if surgopt^="Yes" and amopt="Yes" then switch_nature="Surgery-->Active Monitoring";

	/**1=yes and 2=no for each variable. but a patient should contribute to just one variables.**/
	if surgopt="Yes" or amopt="Yes" then do;
		if max(surgopt_PATANXT_num,AMOPT_PATANXT_num) = 1 then switch_PATANXT="Yes"; else if max(surgopt_PATANXT_num,AMOPT_PATANXT_num) = 2 then switch_PATANXT="No";
		if max(surgopt_PROVRECM_num,AMOPT_PROVRECM_num) = 1 then switch_provrecm="Yes"; else if max(surgopt_PROVRECM_num,AMOPT_PROVRECM_num) = 2 then switch_provrecm="No";
		if max(surgopt_PATPREF_num,AMOPT_PATPREF_num) = 1 then switch_PATPREF="Yes"; else if max(surgopt_PATPREF_num,AMOPT_PATPREF_num) = 2 then switch_PATPREF="No";
		if max(surgopt_RSNOTH_num,AMOPT_RSNOTH_num) = 1 then do;
			if surgopt="Yes" then switch_RSNOTH=strip(propcase("Opted for surgery because "||SURGOPT_RSNOTH)); 
			else if amopt="Yes" then switch_RSNOTH=strip(propcase("Opted for active monitoring because "||AMOPT_RSNOTH)); 
			end;
		else if max(surgopt_RSNOTH_num,AMOPT_RSNOTH_num) = 2 then switch_RSNOTH="No other reason";
	dt_switch=max(dt_surgopt,dt_amopt);
	end;


	label switch_PATANXT="did patient decline arm because of patient anxiety?" switch_provrecm="did patient decline arm because of provider recommendation?"
		  switch_PATPREF="did patient decline arm because of patient preference?" switch_RSNOTH="Was there an unlisted reason the patient declined their arm?"
		  dt_switch="date the patient opted for the other arm";
	format dt_switch date9.;
run;

proc sort data=crossover1;
	by subject dt_switch recordid;
run;

data crossover_count (keep=subject count);
	set crossover1;
	by subject dt_switch;
	retain count;
	if first.subject then count=0;
	count=count+1;
	if last.subject then output;
run;

data crossover2;
	merge crossover1 crossover_count(rename=(count=switch_records));
	by subject;
run;
/** when merging the data, create a variable that identifies patients in this dataset as switching treatment and those not in this dataset as not switching **/

comment CRF: Surgical Summary;
proc sql;
	create table surgicalsummary0 as
	select subject,recordid,cycle,datepart(SURG_DT) as dt_surg label="Date of study surgery" format=date9.,SURGLAT,SURGLAT_STD as SURGLAT_num,SURGTYP, SURGTYP_STD as SURGTYP_num,
		ifc(missing(SURGTYP) or strip(SURGTYP)="Unknown","Missing/Unknown Surgery Type",ifc(SURGTYP^="Mastectomy","Non-Mastectomy",SURGBRSTRECON)) 
			as Reconstruction label="If Mastectomy, was breast reconstruction performed as part of this surgery?)",
		ifn(missing(SURGTYP) or strip(SURGTYP)="Unknown",.M,ifn(SURGTYP^="Mastectomy",.N,SURGBRSTRECON_STD)) as Reconstruction_num,

		ifc(missing(SURGTYP) or strip(SURGTYP)="Unknown","Missing/Unknown Surgery Type",ifc(SURGTYP^="Mastectomy","Non-Mastectomy",DZEXTENT)) 
			as extent_disease label="Reasons for choice of Mastectomy - Extent of Disease?)",
		ifn(missing(SURGTYP) or strip(SURGTYP)="Unknown",.M,ifn(SURGTYP^="Mastectomy",.N,DZEXTENT_STD)) as extent_num,
		ifc(missing(SURGTYP) or strip(SURGTYP)="Unknown","Missing/Unknown Surgery Type",ifc(SURGTYP^="Mastectomy","Non-Mastectomy",RADTCONTRAIND)) 
			as rtcontraind label="Reasons for choice of Mastectomy - Contraindication to radiation therapy?)",
		ifn(missing(SURGTYP) or strip(SURGTYP)="Unknown",.M,ifn(SURGTYP^="Mastectomy",.N,RADTCONTRAIND_STD)) as rtcontraind_num,
		ifc(missing(SURGTYP) or strip(SURGTYP)="Unknown","Missing/Unknown Surgery Type",ifc(SURGTYP^="Mastectomy","Non-Mastectomy",PATPREF)) 
			as ptpreference label="Reasons for choice of Mastectomy - Patient Preference?)",
		ifn(missing(SURGTYP) or strip(SURGTYP)="Unknown",.M,ifn(SURGTYP^="Mastectomy",.N,PATPREF_STD)) as ptpreference_num,
		ifc(missing(SURGTYP) or strip(SURGTYP)="Unknown","Missing/Unknown Surgery Type",ifc(SURGTYP^="Mastectomy","Non-Mastectomy",ifc(^missing(RSNOTHER),ifc(RSNOTHER="Yes",RSNOTHERSP,"No 'other' reason"),' '))) 
			as othermxreas label="Reasons for choice of Mastectomy - Other reason?)",
		ifn(missing(SURGTYP) or strip(SURGTYP)="Unknown",.M,ifn(SURGTYP^="Mastectomy",.N,RSNOTHER_STD)) as othermxreas_num,

		SURGPATHREP,ifn(^missing(SURGPATHREP),1,2) as pathrpt_available label="Was path report submitted (1=Yes, 2=No)",

		HIGHDCISGRADE as pathrpt_dcisgrade,HIGHDCISGRADE_STD as pathrpt_dcisgrade_num,DCISDZEXTENT as pathrpt_dcissize label="DCIS disease extent in cm",
		DCISPRESENT as pathrpt_dcismarg label="Final DCIS margin?", DCISPRESENT_STD as pathrpt_dcismar_num,DCISWIDTH as pathrpt_dciswidth label="Width of closest margin for DCIS",

		INVASIVETUMOR as pathrpt_invyn label="Was invasive tumor present?",INVASIVETUMOR_STD as pathrpt_invyn_num,
		ifn(missing(INVASIVETUMOR),.M,ifn(INVASIVETUMOR="No",.N,INVASIVELARGLESION)) 
			as pathrtp_invsize label="Invasive cancer largest target lesion (pathologic size) in cm",
		ifc(missing(INVASIVETUMOR),"Missing Invasive Tumor Data",ifc(INVASIVETUMOR="No","Not Applicable - No Invasive Tumor Present",HIGHINVGRADE)) 
			as pathrpt_invgrade label="Highest Invasive Cancer Grade",INVPRESENT as pathrpt_invmarg label="Invasive cancer present at the final margin?", 
		INVPRESENT_STD as pathrpt_invmar_num,INVWIDTH as pathrpt_INVWIDTH label="Width of closest margin for invasive cancer",

		ER,ER_STD as ER_num, ERSTAIN,ERSTAINUNK label="whether % staining for ER is unknown", ERSTAININTENS,ERSTAININTENS_STD as ERSTAININTENS_num,
		PGR, PGR_STD as PGR_num,PGRSTAIN,PGRSTAINUNK label="whether % staining for PgR is unknown", PGRSTAININTENS ,
		PGRSTAININTENS_STD as PGRSTAININTENS_num,IHCHER2STAT,IHCHER2STAT_STD as IHCHER2STAT_num,
		FISHHER2NEU,FISHHER2NEU_STD as FISHHER2NEU_num,
		ifn(missing(FISHHER2NEU) or strip(FISHHER2NEU)="Unknown",.M, ifn(FISHHER2NEU="No",.N,FISHHER2NEURATIO)) as FISHHER2NEURATIO label="HER2-neu FISH ratio for study surgery",

		SLNDYN, SLNDYN_STD as SLNDYN_num,
		ifn(missing(SLNDYN),.M, ifn(SLNDYN="No",.N,datepart(SLNDDT))) as dt_slnd format=date9. label="Date of sentinel node biopsy (for study surgery)", 
		ifn(missing(SLNDYN),.M, ifn(SLNDYN="No",.N,SLNDTOTALN)) as slndtotaln  label="Total number of nodes removed during SLND (for study surgery)", 
		ifn(missing(SLNDYN),.M, ifn(SLNDYN="No",.N,SLNDPOSN)) as SLNDPOSN label="Number of positive nodes removed during SLND (for study surgery)", 

		ALNDYN, ALNDYN_STD as ALNDYN_num,
		ifn(missing(ALNDYN),.M, ifn(ALNDYN="No",.N,datepart(ALNDDT))) as dt_alnd format=date9. label="Date of axillary node biopsy (for study surgery)", 
		ifn(missing(ALNDYN),.M, ifn(ALNDYN="No",.N,ALNDAXILN)) as ALNDAXILN  label="Number of axillary lymph nodes in ALND (for study surgery)", 
		ifn(missing(ALNDYN),.M, ifn(ALNDYN="No",.N,ALNDPOSN)) as ALNDPOSN label="Number of positive lymph nodes in ALND (for study surgery)", 

		ADDSURGREQ label="Were additional surgeries required to obtain clear margins (for study surgery)?", ADDSURGREQ_STD as ADDSURGREQ_num,
		ifn(missing(ADDSURGREQ),.M, ifn(ADDSURGREQ="No",.N,NUMADDSURGREQ)) as NUMADDSURGREQ  label="Number of additional surgeries required to obtain clear margins (for study surgery)", 
		DCISMARGSURG label="DCIS margins from study surgery", DCISMARGSURG_STD as DCISMARG_num
	from cometdta.Surgicalsummary
	order by subject asc, recordid asc;
quit;



proc sort data=surgicalsummary0 out=surgicalsummary1;
	where ^missing(dt_surg);
	by subject dt_surg recordid;
run;
data surgicalsummary2;
	set surgicalsummary1;
	by subject dt_surg;
	retain surg_order;
	if first.subject then surg_order =0;
	surg_order=surg_order + 1;
	drop recordid;
	format dt_:;
	informat dt_:
run;
proc contents data=surgicalsummary2 out=vars_surg_int (keep=name label type varnum);
	run;quit;
proc sql noprint;
	select name into :surgvars separated by ' '
	from vars_surg_int
	where name ^in('Subject','surg_order','CYCLE') and find(name,'_num')=0
	order by varnum;
quit;
comment coding technique for transposing multiple variables at once borrowed from here: http://support.sas.com/resources/papers/proceedings13/538-2013.pdf;

comment ALL surgeries;
proc transpose data=surgicalsummary2 out=transp_surgery0 ;
 	by subject surg_order;
	var &surgvars;
run;
proc transpose data=transp_surgery0 prefix=Surg out=transp_surgery1 (where=(not missing(_NAME_)) /*drop=_name_*/)
	delimiter=_;
 	by subject;
 	id surg_order _name_ ;
 	var col1;
run;

/** patients may have more surgeries in later updates. as for now (5Aug2021), the most is 5.**/
data surgsummaryfinal;
	set transp_surgery1 (rename=(Surg1_dt_surg=Surg1_dt_surg0 Surg1_pathrpt_available=Surg1_pathrpt_available0 Surg1_pathrpt_dcissize=Surg1_pathrpt_dcissize0 
								 Surg1_pathrtp_invsize=Surg1_pathrtp_invsize0 Surg1_ERSTAIN=Surg1_ERSTAIN0 Surg1_ERSTAINUNK=Surg1_ERSTAINUNK0 Surg1_pgRSTAIN=Surg1_pgRSTAIN0
								 Surg1_PgRSTAINUNK=Surg1_PgRSTAINUNK0 Surg1_FISHHER2NEURATIO=Surg1_FISHHER2NEURATIO0 Surg1_dt_slnd=Surg1_dt_slnd0 Surg1_slndtotaln=Surg1_slndtotaln0
								 Surg1_SLNDPOSN=Surg1_SLNDPOSN0 Surg1_dt_alnd=Surg1_dt_alnd0 Surg1_ALNDAXILN=Surg1_ALNDAXILN0 Surg1_ALNDPOSN=Surg1_ALNDPOSN0 
								 Surg1_NUMADDSURGREQ=Surg1_NUMADDSURGREQ0

								 Surg2_dt_surg=Surg2_dt_surg0 Surg2_pathrpt_available=Surg2_pathrpt_available0 Surg2_pathrpt_dcissize=Surg2_pathrpt_dcissize0 
								 Surg2_pathrtp_invsize=Surg2_pathrtp_invsize0 Surg2_ERSTAIN=Surg2_ERSTAIN0 Surg2_ERSTAINUNK=Surg2_ERSTAINUNK0 Surg2_pgRSTAIN=Surg2_pgRSTAIN0
								 Surg2_PgRSTAINUNK=Surg2_PgRSTAINUNK0 Surg2_FISHHER2NEURATIO=Surg2_FISHHER2NEURATIO0 Surg2_dt_slnd=Surg2_dt_slnd0 Surg2_slndtotaln=Surg2_slndtotaln0
								 Surg2_SLNDPOSN=Surg2_SLNDPOSN0 Surg2_dt_alnd=Surg2_dt_alnd0 Surg2_ALNDAXILN=Surg2_ALNDAXILN0 Surg2_ALNDPOSN=Surg2_ALNDPOSN0 
								 Surg2_NUMADDSURGREQ=Surg2_NUMADDSURGREQ0

								 Surg3_dt_surg=Surg3_dt_surg0 Surg3_pathrpt_available=Surg3_pathrpt_available0 Surg3_pathrpt_dcissize=Surg3_pathrpt_dcissize0 
								 Surg3_pathrtp_invsize=Surg3_pathrtp_invsize0 Surg3_ERSTAIN=Surg3_ERSTAIN0 Surg3_ERSTAINUNK=Surg3_ERSTAINUNK0 Surg3_pgRSTAIN=Surg3_pgRSTAIN0
								 Surg3_PgRSTAINUNK=Surg3_PgRSTAINUNK0 Surg3_FISHHER2NEURATIO=Surg3_FISHHER2NEURATIO0 Surg3_dt_slnd=Surg3_dt_slnd0 Surg3_slndtotaln=Surg3_slndtotaln0
								 Surg3_SLNDPOSN=Surg3_SLNDPOSN0 Surg3_dt_alnd=Surg3_dt_alnd0 Surg3_ALNDAXILN=Surg3_ALNDAXILN0 Surg3_ALNDPOSN=Surg3_ALNDPOSN0 
								 Surg3_NUMADDSURGREQ=Surg3_NUMADDSURGREQ0

								 Surg4_dt_surg=Surg4_dt_surg0 Surg4_pathrpt_available=Surg4_pathrpt_available0 Surg4_pathrpt_dcissize=Surg4_pathrpt_dcissize0 
								 Surg4_pathrtp_invsize=Surg4_pathrtp_invsize0 Surg4_ERSTAIN=Surg4_ERSTAIN0 Surg4_ERSTAINUNK=Surg4_ERSTAINUNK0 Surg4_pgRSTAIN=Surg4_pgRSTAIN0
								 Surg4_PgRSTAINUNK=Surg4_PgRSTAINUNK0 Surg4_FISHHER2NEURATIO=Surg4_FISHHER2NEURATIO0 Surg4_dt_slnd=Surg4_dt_slnd0 Surg4_slndtotaln=Surg4_slndtotaln0
								 Surg4_SLNDPOSN=Surg4_SLNDPOSN0 Surg4_dt_alnd=Surg4_dt_alnd0 Surg4_ALNDAXILN=Surg4_ALNDAXILN0 Surg4_ALNDPOSN=Surg4_ALNDPOSN0 
								 Surg4_NUMADDSURGREQ=Surg4_NUMADDSURGREQ0

								 Surg5_dt_surg=Surg5_dt_surg0 Surg5_pathrpt_available=Surg5_pathrpt_available0 Surg5_pathrpt_dcissize=Surg5_pathrpt_dcissize0 
								 Surg5_pathrtp_invsize=Surg5_pathrtp_invsize0 Surg5_ERSTAIN=Surg5_ERSTAIN0 Surg5_ERSTAINUNK=Surg5_ERSTAINUNK0 Surg5_pgRSTAIN=Surg5_pgRSTAIN0
								 Surg5_PgRSTAINUNK=Surg5_PgRSTAINUNK0 Surg5_FISHHER2NEURATIO=Surg5_FISHHER2NEURATIO0 Surg5_dt_slnd=Surg5_dt_slnd0 Surg5_slndtotaln=Surg5_slndtotaln0
								 Surg5_SLNDPOSN=Surg5_SLNDPOSN0 Surg5_dt_alnd=Surg5_dt_alnd0 Surg5_ALNDAXILN=Surg5_ALNDAXILN0 Surg5_ALNDPOSN=Surg5_ALNDPOSN0 
								 Surg5_NUMADDSURGREQ=Surg5_NUMADDSURGREQ0));

	Surg1_dt_surg=input(strip(Surg1_dt_surg0),8.); Surg1_pathrpt_available=input(strip(Surg1_pathrpt_available0),8.);
	Surg1_pathrpt_dcissize=input(strip(Surg1_pathrpt_dcissize0),8.); Surg1_pathrtp_invsize=input(strip(Surg1_pathrtp_invsize0),8.);
	Surg1_ERSTAIN=input(strip(Surg1_ERSTAIN0),8.); Surg1_ERSTAINUNK=input(strip(Surg1_ERSTAINUNK0),8.);
	Surg1_pgRSTAIN=input(strip(Surg1_PgRSTAIN0),8.); Surg1_PgRSTAINUNK=input(strip(Surg1_PgRSTAINUNK0),8.); Surg1_FISHHER2NEURATIO=input(strip(Surg1_FISHHER2NEURATIO0),8.);
	Surg1_dt_slnd=input(strip(Surg1_dt_slnd),8.); Surg1_slndtotaln=input(strip(Surg1_slndtotaln0),8.); Surg1_SLNDPOSN=input(strip(Surg1_SLNDPOSN0),8.);
	Surg1_dt_alnd=input(strip(Surg1_dt_alnd0),8.); Surg1_ALNDAXILN=input(strip(Surg1_ALNDAXILN0),8.); Surg1_ALNDPOSN=input(strip(Surg1_ALNDPOSN0),8.);
	Surg1_NUMADDSURGREQ=input(strip(Surg1_NUMADDSURGREQ0),8.);

	Surg2_dt_surg=input(strip(Surg2_dt_surg0),8.); Surg2_pathrpt_available=input(strip(Surg2_pathrpt_available0),8.);
	Surg2_pathrpt_dcissize=input(strip(Surg2_pathrpt_dcissize0),8.); Surg2_pathrtp_invsize=input(strip(Surg2_pathrtp_invsize0),8.);
	Surg2_ERSTAIN=input(strip(Surg2_ERSTAIN0),8.); Surg2_ERSTAINUNK=input(strip(Surg2_ERSTAINUNK0),8.);
	Surg2_pgRSTAIN=input(strip(Surg2_PgRSTAIN0),8.); Surg2_PgRSTAINUNK=input(strip(Surg2_PgRSTAINUNK0),8.); Surg2_FISHHER2NEURATIO=input(strip(Surg2_FISHHER2NEURATIO0),8.);
	Surg2_dt_slnd=input(strip(Surg2_dt_slnd),8.); Surg2_slndtotaln=input(strip(Surg2_slndtotaln0),8.); Surg2_SLNDPOSN=input(strip(Surg2_SLNDPOSN0),8.);
	Surg2_dt_alnd=input(strip(Surg2_dt_alnd0),8.); Surg2_ALNDAXILN=input(strip(Surg2_ALNDAXILN0),8.); Surg2_ALNDPOSN=input(strip(Surg2_ALNDPOSN0),8.);
	Surg2_NUMADDSURGREQ=input(strip(Surg2_NUMADDSURGREQ0),8.);

	Surg3_dt_surg=input(strip(Surg3_dt_surg0),8.); Surg3_pathrpt_available=input(strip(Surg3_pathrpt_available0),8.);
	Surg3_pathrpt_dcissize=input(strip(Surg3_pathrpt_dcissize0),8.); Surg3_pathrtp_invsize=input(strip(Surg3_pathrtp_invsize0),8.);
	Surg3_ERSTAIN=input(strip(Surg3_ERSTAIN0),8.); Surg3_ERSTAINUNK=input(strip(Surg3_ERSTAINUNK0),8.);
	Surg3_pgRSTAIN=input(strip(Surg3_PgRSTAIN0),8.); Surg3_PgRSTAINUNK=input(strip(Surg3_PgRSTAINUNK0),8.); Surg3_FISHHER2NEURATIO=input(strip(Surg3_FISHHER2NEURATIO0),8.);
	Surg3_dt_slnd=input(strip(Surg3_dt_slnd),8.); Surg3_slndtotaln=input(strip(Surg3_slndtotaln0),8.); Surg3_SLNDPOSN=input(strip(Surg3_SLNDPOSN0),8.);
	Surg3_dt_alnd=input(strip(Surg3_dt_alnd0),8.); Surg3_ALNDAXILN=input(strip(Surg3_ALNDAXILN0),8.); Surg3_ALNDPOSN=input(strip(Surg3_ALNDPOSN0),8.);
	Surg3_NUMADDSURGREQ=input(strip(Surg3_NUMADDSURGREQ0),8.);

	Surg4_dt_surg=input(strip(Surg4_dt_surg0),8.); Surg4_pathrpt_available=input(strip(Surg4_pathrpt_available0),8.);
	Surg4_pathrpt_dcissize=input(strip(Surg4_pathrpt_dcissize0),8.); Surg4_pathrtp_invsize=input(strip(Surg4_pathrtp_invsize0),8.);
	Surg4_ERSTAIN=input(strip(Surg4_ERSTAIN0),8.); Surg4_ERSTAINUNK=input(strip(Surg4_ERSTAINUNK0),8.);
	Surg4_pgRSTAIN=input(strip(Surg4_PgRSTAIN0),8.); Surg4_PgRSTAINUNK=input(strip(Surg4_PgRSTAINUNK0),8.); Surg4_FISHHER2NEURATIO=input(strip(Surg4_FISHHER2NEURATIO0),8.);
	Surg4_dt_slnd=input(strip(Surg4_dt_slnd),8.); Surg4_slndtotaln=input(strip(Surg4_slndtotaln0),8.); Surg4_SLNDPOSN=input(strip(Surg4_SLNDPOSN0),8.);
	Surg4_dt_alnd=input(strip(Surg4_dt_alnd0),8.); Surg4_ALNDAXILN=input(strip(Surg4_ALNDAXILN0),8.); Surg4_ALNDPOSN=input(strip(Surg4_ALNDPOSN0),8.);
	Surg4_NUMADDSURGREQ=input(strip(Surg4_NUMADDSURGREQ0),8.);

	Surg5_dt_surg=input(strip(Surg5_dt_surg0),8.); Surg5_pathrpt_available=input(strip(Surg5_pathrpt_available0),8.);
	Surg5_pathrpt_dcissize=input(strip(Surg5_pathrpt_dcissize0),8.); Surg5_pathrtp_invsize=input(strip(Surg5_pathrtp_invsize0),8.);
	Surg5_ERSTAIN=input(strip(Surg5_ERSTAIN0),8.); Surg5_ERSTAINUNK=input(strip(Surg5_ERSTAINUNK0),8.);
	Surg5_pgRSTAIN=input(strip(Surg5_PgRSTAIN0),8.); Surg5_PgRSTAINUNK=input(strip(Surg5_PgRSTAINUNK0),8.); Surg5_FISHHER2NEURATIO=input(strip(Surg5_FISHHER2NEURATIO0),8.);
	Surg5_dt_slnd=input(strip(Surg5_dt_slnd),8.); Surg5_slndtotaln=input(strip(Surg5_slndtotaln0),8.); Surg5_SLNDPOSN=input(strip(Surg5_SLNDPOSN0),8.);
	Surg5_dt_alnd=input(strip(Surg5_dt_alnd0),8.); Surg5_ALNDAXILN=input(strip(Surg5_ALNDAXILN0),8.); Surg5_ALNDPOSN=input(strip(Surg5_ALNDPOSN0),8.);
	Surg5_NUMADDSURGREQ=input(strip(Surg5_NUMADDSURGREQ0),8.);

	drop _NAME_ Surg1_dt_surg0 Surg1_pathrpt_available0 Surg1_pathrpt_dcissize0 Surg1_pathrtp_invsize0 Surg1_ERSTAIN0 Surg1_ERSTAINUNK0 Surg1_pgRSTAIN0 Surg1_PgRSTAINUNK0 
			Surg1_FISHHER2NEURATIO0 Surg1_dt_slnd0 Surg1_slndtotaln0 Surg1_SLNDPOSN0 Surg1_dt_alnd0 Surg1_ALNDAXILN0 Surg1_ALNDPOSN0 Surg1_NUMADDSURGREQ0

			Surg2_dt_surg0 Surg2_pathrpt_available0 Surg2_pathrpt_dcissize0 Surg2_pathrtp_invsize0 Surg2_ERSTAIN0 Surg2_ERSTAINUNK0 Surg2_pgRSTAIN0 Surg2_PgRSTAINUNK0 
			Surg2_FISHHER2NEURATIO0 Surg2_dt_slnd0 Surg2_slndtotaln0 Surg2_SLNDPOSN0 Surg2_dt_alnd0 Surg2_ALNDAXILN0 Surg2_ALNDPOSN0 Surg2_NUMADDSURGREQ0

			Surg3_dt_surg0 Surg3_pathrpt_available0 Surg3_pathrpt_dcissize0 Surg3_pathrtp_invsize0 Surg3_ERSTAIN0 Surg3_ERSTAINUNK0 Surg3_pgRSTAIN0 Surg3_PgRSTAINUNK0 
			Surg3_FISHHER2NEURATIO0 Surg3_dt_slnd0 Surg3_slndtotaln0 Surg3_SLNDPOSN0 Surg3_dt_alnd0 Surg3_ALNDAXILN0 Surg3_ALNDPOSN0 Surg3_NUMADDSURGREQ0

			Surg4_dt_surg0 Surg4_pathrpt_available0 Surg4_pathrpt_dcissize0 Surg4_pathrtp_invsize0 Surg4_ERSTAIN0 Surg4_ERSTAINUNK0 Surg4_pgRSTAIN0 Surg4_PgRSTAINUNK0 
			Surg4_FISHHER2NEURATIO0 Surg4_dt_slnd0 Surg4_slndtotaln0 Surg4_SLNDPOSN0 Surg4_dt_alnd0 Surg4_ALNDAXILN0 Surg4_ALNDPOSN0 Surg4_NUMADDSURGREQ0

			Surg5_dt_surg0 Surg5_pathrpt_available0 Surg5_pathrpt_dcissize0 Surg5_pathrtp_invsize0 Surg5_ERSTAIN0 Surg5_ERSTAINUNK0 Surg5_pgRSTAIN0 Surg5_PgRSTAINUNK0 
			Surg5_FISHHER2NEURATIO0 Surg5_dt_slnd0 Surg5_slndtotaln0 Surg5_SLNDPOSN0 Surg5_dt_alnd0 Surg5_ALNDAXILN0 Surg5_ALNDPOSN0 Surg5_NUMADDSURGREQ0;

	format Surg1_dt_surg Surg1_dt_slnd Surg1_dt_alnd Surg2_dt_surg Surg2_dt_slnd Surg2_dt_alnd Surg3_dt_surg Surg3_dt_slnd Surg3_dt_alnd Surg4_dt_surg Surg4_dt_slnd Surg4_dt_alnd 
				Surg5_dt_surg Surg5_dt_slnd Surg5_dt_alnd date9.;

	label Surg1_dt_surg="date of study surgery 1" Surg1_pathrpt_available="Path report available for study surgery 1? (1=yes, 0=no)"
	Surg1_pathrpt_dcissize="DCIS size in cm reported from study surgery 1" Surg1_pathrtp_invsize="Invasive size in cm reported from study surgery 1" 
	Surg1_ERSTAIN="% ER staining reported from study surgery 1" Surg1_ERSTAINUNK="% staining, ER unknown for study surgery 1 (1=yes, 0=no)" 
	Surg1_pgRSTAIN="% PgR staining reported from study surgery 1"  Surg1_PgRSTAINUNK="% staining, PgR unknown for study surgery 1 (1=yes, 0=no)"  
	Surg1_FISHHER2NEURATIO=" HER2-neu FISH ratio for study surgery 1" Surg1_dt_slnd="Date of sentinel node biopsy for study surgery 1"  
	Surg1_slndtotaln="total number of nodes removed during SLND for study surgery 1"  Surg1_SLNDPOSN="Number of positive nodes removed during SLND for study surgery 1" 
	Surg1_dt_alnd="Date of axillary lymph node dissection for study surgery 1"  Surg1_ALNDAXILN="total number of axillary nodes in ALND for study surgery 1"  
	Surg1_ALNDPOSN="Number of positive lymph nodes in ALND for study surgery 1" 
	Surg1_NUMADDSURGREQ="Number of additional surgeries required to obtain clear margins for surgery 1"

	Surg2_dt_surg="date of study surgery 2" Surg2_pathrpt_available="Path report available for study surgery 2? (1=yes, 0=no)"
	Surg2_pathrpt_dcissize="DCIS size in cm reported from study surgery 2" Surg2_pathrtp_invsize="Invasive size in cm reported from study surgery 2" 
	Surg2_ERSTAIN="% ER staining reported from study surgery 2" Surg2_ERSTAINUNK="% staining, ER unknown for study surgery 2 (1=yes, 0=no)" 
	Surg2_pgRSTAIN="% PgR staining reported from study surgery 2"  Surg2_PgRSTAINUNK="% staining, PgR unknown for study surgery 2 (1=yes, 0=no)"  
	Surg2_FISHHER2NEURATIO=" HER2-neu FISH ratio for study surgery 2" Surg2_dt_slnd="Date of sentinel node biopsy for study surgery 2"  
	Surg2_slndtotaln="total number of nodes removed during SLND for study surgery 2"  Surg2_SLNDPOSN="Number of positive nodes removed during SLND for study surgery 2" 
	Surg2_dt_alnd="Date of axillary lymph node dissection for study surgery 2"  Surg2_ALNDAXILN="total number of axillary nodes in ALND for study surgery 2"  
	Surg2_ALNDPOSN="Number of positive lymph nodes in ALND for study surgery 2" 
	Surg2_NUMADDSURGREQ="Number of additional surgeries required to obtain clear margins for surgery 2"

	Surg3_dt_surg="date of study surgery 3" Surg3_pathrpt_available="Path report available for study surgery 3? (1=yes, 0=no)"
	Surg3_pathrpt_dcissize="DCIS size in cm reported from study surgery 3" Surg3_pathrtp_invsize="Invasive size in cm reported from study surgery 3" 
	Surg3_ERSTAIN="% ER staining reported from study surgery 3" Surg3_ERSTAINUNK="% staining, ER unknown for study surgery 3 (1=yes, 0=no)" 
	Surg3_pgRSTAIN="% PgR staining reported from study surgery 3"  Surg3_PgRSTAINUNK="% staining, PgR unknown for study surgery 3 (1=yes, 0=no)"  
	Surg3_FISHHER2NEURATIO=" HER2-neu FISH ratio for study surgery 3" Surg3_dt_slnd="Date of sentinel node biopsy for study surgery 3"  
	Surg3_slndtotaln="total number of nodes removed during SLND for study surgery 3"  Surg3_SLNDPOSN="Number of positive nodes removed during SLND for study surgery 3" 
	Surg3_dt_alnd="Date of axillary lymph node dissection for study surgery 3"  Surg3_ALNDAXILN="total number of axillary nodes in ALND for study surgery 3"  
	Surg3_ALNDPOSN="Number of positive lymph nodes in ALND for study surgery 3" 
	Surg3_NUMADDSURGREQ="Number of additional surgeries required to obtain clear margins for surgery 3"

	Surg4_dt_surg="date of study surgery 4" Surg4_pathrpt_available="Path report available for study surgery 4? (1=yes, 0=no)"
	Surg4_pathrpt_dcissize="DCIS size in cm reported from study surgery 4" Surg4_pathrtp_invsize="Invasive size in cm reported from study surgery 4" 
	Surg4_ERSTAIN="% ER staining reported from study surgery 4" Surg4_ERSTAINUNK="% staining, ER unknown for study surgery 4 (1=yes, 0=no)" 
	Surg4_pgRSTAIN="% PgR staining reported from study surgery 4"  Surg4_PgRSTAINUNK="% staining, PgR unknown for study surgery 4 (1=yes, 0=no)"  
	Surg4_FISHHER2NEURATIO=" HER2-neu FISH ratio for study surgery 4" Surg4_dt_slnd="Date of sentinel node biopsy for study surgery 4"  
	Surg4_slndtotaln="total number of nodes removed during SLND for study surgery 4"  Surg4_SLNDPOSN="Number of positive nodes removed during SLND for study surgery 4" 
	Surg4_dt_alnd="Date of axillary lymph node dissection for study surgery 4"  Surg4_ALNDAXILN="total number of axillary nodes in ALND for study surgery 4"  
	Surg4_ALNDPOSN="Number of positive lymph nodes in ALND for study surgery 4" 
	Surg4_NUMADDSURGREQ="Number of additional surgeries required to obtain clear margins for surgery 4"

	Surg5_dt_surg="date of study surgery 5" Surg5_pathrpt_available="Path report available for study surgery 5? (1=yes, 0=no)"
	Surg5_pathrpt_dcissize="DCIS size in cm reported from study surgery 5" Surg5_pathrtp_invsize="Invasive size in cm reported from study surgery 5" 
	Surg5_ERSTAIN="% ER staining reported from study surgery 5" Surg5_ERSTAINUNK="% staining, ER unknown for study surgery 5 (1=yes, 0=no)" 
	Surg5_pgRSTAIN="% PgR staining reported from study surgery 5"  Surg5_PgRSTAINUNK="% staining, PgR unknown for study surgery 5 (1=yes, 0=no)"  
	Surg5_FISHHER2NEURATIO=" HER2-neu FISH ratio for study surgery 5" Surg5_dt_slnd="Date of sentinel node biopsy for study surgery 5"  
	Surg5_slndtotaln="total number of nodes removed during SLND for study surgery 5"  Surg5_SLNDPOSN="Number of positive nodes removed during SLND for study surgery 5" 
	Surg5_dt_alnd="Date of axillary lymph node dissection for study surgery 5"  Surg5_ALNDAXILN="total number of axillary nodes in ALND for study surgery 5"  
	Surg5_ALNDPOSN="Number of positive lymph nodes in ALND for study surgery 5" 
	Surg5_NUMADDSURGREQ="Number of additional surgeries required to obtain clear margins for surgery 5";


run;

comment CRF: End of Study (Study Withdrawal);
proc sql;
	create table Withdrawal as
	select subject,recordid,datepart(ENDAT_DT) as dt_offstudy format=date9. label="date patient opted to withdraw or completed protocol mandated follow-up",
		ENDATFLLWCMPLT as Ostrzn_completed label="Follow up completed per protocol criteria (1=yes, 0=no)", ENDATDTHONSTUDY as Ostrzn_death label="Death on study (1=yes, 0=no)",
		ENDATWTHDRAWAFTER as Ostrzn_wdafflu label="Patient Withdrawal/Refusal After Beginning Protocol Mandated Follow-up (1=yes, 0=no)",
		ENDATWTHDRAWBEGIN as Ostrzn_wdb4flu label="Patient Withdrawal/Refusal Prior to Beginning Protocol Mandated Follow-up (1=yes, 0=no)",
		ifc(ENDATOTHER=1,ENDATCOM,"No 'other' reason") as Ostrzn_other label="Reasons for withdrawal - Other, specify",
		ifc( (ENDATFLLWCMPLT+ENDATDTHONSTUDY+ENDATWTHDRAWAFTER+ENDATWTHDRAWBEGIN+ENDATOTHER) > 1,ENDATCOM,
				ifc(ENDATFLLWCMPLT=1,"Follow up completed per protocol criteria",
						ifc(ENDATDTHONSTUDY=1,"Death On Study",
							ifc(ENDATWTHDRAWAFTER=1,"Patient Withdrawal/Refusal After Beginning Protocol Mandated Follow-up",
								ifc(ENDATWTHDRAWBEGIN=1,"Patient Withdrawal/Refusal Prior to Beginning Protocol Mandated Follow-up",ENDATCOM)
								)
							)
					) 
			) as Ofstrzn_summ
	from cometdta.END_AT
	order by subject asc, recordid asc;
quit;



data temp_crossmerge(drop=recordid);
	merge randomization(in=ina keep=subject REGIME_NAME_DRV dt_randomized) crossover2 (in=inb) surgsummaryfinal demographics_a demographics_b withdrawal;
	by subject;
	switched_allocation=(inb);
	if ina;
run;

proc contents data=temp_crossmerge;
	ods select variables;
run;quit;

libname newdta "H:\DCI\Breast\COMET\data\created";

proc sql noprint;
	create table newdta.cometsummary as
	select subject,dt_randomized,REGIME_NAME_DRV,switched_allocation label="Did patient switch allocations? (1=yes, 0=no)",switch_records  
			label="How many times is patient in the switching data",dt_switch,switch_nature,SURGOPT,AMOPT,switch_PATANXT,switch_PATPREF,switch_provrecm,switch_RSNOTH,
			surgopt_DCISCHNGE,surgopt_DCISNEW,AMOPT_SURGPOORCAND,site,Surg1_dt_surg,Surg1_SURGTYP,Surg1_Reconstruction,CANDFORLUMPECTMY,DCISLAT,
			Surg1_SURGLAT,Surg1_pathrpt_dcisgrade,Surg1_pathrpt_dcissize,
			Surg1_pathrpt_invgrade,Surg1_pathrtp_invsize,Surg1_ptpreference,Surg2_dt_surg,Surg2_SURGTYP,Surg2_SURGLAT,Surg2_Reconstruction,Surg2_pathrpt_dcisgrade,Surg2_pathrpt_dcissize,
			Surg2_pathrpt_invgrade,Surg2_pathrtp_invsize,Surg2_ptpreference,Surg3_dt_surg,Surg3_SURGTYP,Surg3_SURGLAT,Surg3_Reconstruction,Surg3_pathrpt_dcisgrade,Surg3_pathrpt_dcissize,
			Surg3_pathrpt_invgrade,Surg3_pathrtp_invsize,Surg3_ptpreference,dt_offstudy,Ofstrzn_summ,(dt_randomized-dt_birth)/(365.25) as age_randomization,RACE,race_comb,
			ETHNICITY,MENOSTATRAND,PREGFULLTERM,first_preg_age,cnr_children_born,daughter_count,son_count,ECOGPSBSL_STD,cnr_bmi,hrt_ever,hrt_current,dt_last_hpt
	from temp_crossmerge
	order by subject asc,dt_switch asc;
quit;

proc sort data=newdta.cometsummary out=comet2;
	where ^(switched_allocation=1 and missing(switch_nature));
	by subject dt_switch;
run;

data comet3 comet4;
	set comet2;
	by subject dt_switch;
	studysurg= (n(Surg1_dt_surg,Surg2_dt_surg,Surg3_dt_surg)>0);
	monthstosurg=(min(Surg1_dt_surg,Surg2_dt_surg,Surg3_dt_surg)-dt_randomized)/(362.25/12);
	if ^missing(REGIME_NAME_DRV);
	if last.subject then output comet4;
	output comet3;
run;

options orientation=landscape;
ods rtf file="H:\DCI\Breast\COMET\Comet summary for Terry &sysdate..rtf" style=journal startpage=never bodytitle;

title 'general summary - among patients who are not missing randomized group and if in the crossover data are confirmed to have switched groups at least once.';
proc tabulate data=comet4 order=freq;
	class switch_nature switched_allocation race race_comb ethnicity studysurg REGIME_NAME_DRV/missing;
	classlev _all_ / style=[indent=15];
	*var age_randomization monthstosurg cnr_bmi;
	table all=' ',(REGIME_NAME_DRV*switched_allocation*studysurg='Surgery on Study (1=yes,0=no)')*n=' '*f=6.0 /nocellmerge misstext='0';
run;

title2'Same table if limited to patients with 1 switch record';
proc tabulate data=comet4 order=freq;
	where switch_records = 1;
	class switch_nature switched_allocation race race_comb ethnicity studysurg REGIME_NAME_DRV/missing;
	classlev _all_ / style=[indent=15];
	*var age_randomization monthstosurg cnr_bmi;
	table all=' ',(REGIME_NAME_DRV*switched_allocation*studysurg='Surgery on Study (1=yes,0=no)')*n=' '*f=6.0 /nocellmerge misstext='0';
run;

title'Patients with just one switch record';
title2'all';
proc freq data=comet4;
	where switch_records = 1;
	tables switch_nature /missing;
	tables switch_nature*(switch_PATANXT switch_Provrecm switch_PATpref)/nocol nopercent missing;
run;
title2'switched to surgery';
proc freq data=comet4;
	where switch_records = 1 and switch_nature="Active Monitoring-->Surgery";
	tables surgopt_DCISCHNGE surgopt_DCISNEW switch_rsnoth/missing;
run;
title2'switched to AM';
proc freq data=comet4;
	where switch_records = 1 and switch_nature="Surgery-->Active Monitoring ";
	tables AMOPT_SURGPOORCAND switch_rsnoth/missing;
run;
 ods startpage=now;

title2 "No indication why they're in the switch data until combined with the surgery data (in some cases)";
title3 "AKA the data needs to be checked on their end";
proc sql;
	select subject,REGIME_NAME_DRV,dt_randomized,dt_switch,surgopt,amopt,Surg1_dt_surg,Surg1_SURGTYP,Surg1_SURGLAT,dt_offstudy,Ofstrzn_summ
	from newdta.cometsummary
	where switch_records = 1 and missing(switch_nature) ;
quit;
title'Patients with more than one switch record';
title2;
proc sql;
	select subject,REGIME_NAME_DRV, dt_randomized,dt_switch,switch_nature,Surg1_dt_surg,Surg1_SURGTYP,dt_offstudy,Ofstrzn_summ
	from comet3
	where switch_records > 1;
quit;
ods rtf close;



