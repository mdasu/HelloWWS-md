<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="3.0" 
	xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
    xmlns:wd="urn:com.workday/bsvc"
    exclude-result-prefixes="xs wd">
    
    <!-- 
    		This stylesheet has been designed to stream-process extremely large aggregated webservice responses without the need to
    		first split the results.  The design of the stylesheet is such that only the data for an individual Worker is brought into memory
    		at any one time.  As a result we can easily process gigabytes of XML data which might otherwise cause the system to run out
    		of memory if we attempted to transform it in a non-streaming single in-memory data structure.
     -->

    <!--
        We are emitting XML from this integration.  Note that we have set indent="no on the output.  Use of indent="yes" should be avoided
        where possible, and certainly in production code, since it can increase the size of the output document by up to 30% and degrade the
        performance of any other processing which then performed on that document whether thqt processing occurs within Workday's integration
        cloud or in another system.
        -->
    
    <xsl:output method="xml" indent="no"/>
    
    <!-- 
    		Declare the default mode on this stylesheet to be streamable and that any unmatched nodes should be skipped but their children, if any, should be processed for matching templates.
     -->
     
    <xsl:mode streamable="yes" on-no-match="shallow-skip"/>
    
 
    <xsl:template match="Workers">
        <Summaries>
            <Workers>
 
                <!--
                    Iterate over the Worker elements in the default (streaming) mode but use the copy-of() function to bring a single element at a time into memory and then
                    process that in-memory data.  This so called burst-mode streaming approach allows us to produce simpler streaming XSLT than would be the case if we needed
                    to construct it so that only a single element and text value is held in memory at any one point.  Pure streaming approaches utilising xsl:accumulator and
                    xsl:fork will yield higher performance and are worthwhile when they can be used without significant complexity but that usage would not be justified
                    here.
                    
                    Note that we only need to use xsl:iterate in this case (in place of xsl:for-each or xsl:apply-templates) since we've given ourselves the additional
                    complication that we want to output a footer record containing the count of the number of workers processed.  Iterate allows us to
                    pass values from one iteration to the next which gives us the ability to increment a count after every worker.
                -->
                
                <xsl:iterate select="copy-of(wd:Worker)">
                    
                    <xsl:param name="count" select="0" as="xs:integer"/>
                    <!--
                        After all the Workers have been processed we want to output a footer record containing a count of the number of workers
                        processed
                        -->
                    
                    <xsl:on-completion>
                        <Footer>
                            <Count><xsl:value-of select="$count"/></Count>
                        </Footer>
                    </xsl:on-completion>

                    <WorkerSummary>
                        
                        <ReferenceID><xsl:value-of select="wd:Worker_Reference/wd:ID[@wd:type=('Employee_ID','Contingent_Worker_ID')]"/></ReferenceID>
                        
                        <Name>
                            <xsl:value-of select="wd:Worker_Data/wd:Personal_Data/wd:Name_Data/wd:Legal_Name_Data/wd:Name_Detail_Data[1]/concat(wd:First_Name,' ',wd:Last_Name)"/>
                        </Name>
 
                        <!-- 
        		    		Output the business title of the primary Position.  Note that we test whether it is the primary position by using xs:boolean(@wd:Primary_Job).  This is
        		    		considerably safer than using @wd:Primary_Job='1' since the Primary_Job attribute is defined as an XML boolean and can therefore have the
        		    		value "1" or "true" (with any amount of leading or trailing whitespace) in order to mean boolean true.  Using @wd:Primary_Job='1' would fail to work
        		    		correctly if the webservice ever returned the perfectly valid wd:Primary_Job="true"
		                  -->
                        <Title><xsl:value-of select="wd:Worker_Data/wd:Employment_Data/wd:Worker_Job_Data[xs:boolean(@wd:Primary_Job)]/wd:Position_Data/wd:Business_Title"/></Title>
                        
                    </WorkerSummary>
                    
                    <!--
                        Incremeent the count of workers processed by this transform and pass that to the next iteration (the next Worker element found or the on-completion processing)
                        -->
                    
                    <xsl:next-iteration>
                        <xsl:with-param name="count" select="1+$count"/>
                    </xsl:next-iteration>                   
                    
                </xsl:iterate>
            </Workers>
        </Summaries>
    </xsl:template>
		
</xsl:stylesheet>