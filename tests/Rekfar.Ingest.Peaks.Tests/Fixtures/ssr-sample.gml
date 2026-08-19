<?xml version="1.0" encoding="UTF-8"?>
<!--
    Test fixture for the Rekfar peak import.

    Nine features taken verbatim from the Kartverket "Stedsnavn" whole-country extract
    (Basisdata_0000_Norge_4258_Stedsnavn_GML, 2026-08-14), each kept because it isolates one
    decision the parser has to get right. The GML envelope is the original file's; only the
    selection of features and the case comments are ours.

    Source: Kartverket, Stedsnavn (StedsnavnForVanligBruk 20231001)
    Licence: CC BY 4.0 — © Kartverket
    https://kartkatalog.geonorge.no/metadata/stedsnavn/30caed2f-454e-44be-b5cc-26bb5c0110ca
-->
<gml:FeatureCollection xmlns:app="https://skjema.geonorge.no/SOSI/produktspesifikasjon/StedsnavnForVanligBruk/20231001" xmlns:gco="http://www.isotc211.org/2005/gco" xmlns:gmd="http://www.isotc211.org/2005/gmd" xmlns:gml="http://www.opengis.net/gml/3.2" xmlns:gsr="http://www.isotc211.org/2005/gsr" xmlns:gss="http://www.isotc211.org/2005/gss" xmlns:gts="http://www.isotc211.org/2005/gts" xmlns:sc="http://www.interactive-instruments.de/ShapeChange/AppInfo" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" gml:id="idd5eb9716-4fc1-4b61-8936-2e3b00fa27db" xsi:schemaLocation="https://skjema.geonorge.no/SOSI/produktspesifikasjon/StedsnavnForVanligBruk/20231001 https://skjema.geonorge.no/SOSI/produktspesifikasjon/StedsnavnForVanligBruk/20231001/StedsnavnForVanligBruk.xsd">
	<gml:boundedBy>
		<gml:Envelope srsName="urn:ogc:def:crs:EPSG::4258" srsDimension="2">
			<gml:lowerCorner>53.967286 -43.911558</gml:lowerCorner>
			<gml:upperCorner>80.470691 55.930598</gml:upperCorner>
		</gml:Envelope>
	</gml:boundedBy>
	<!-- fixture case: single_point -->
<gml:featureMember>
		<app:Sted gml:id="id68f9d5f5-25fd-4df5-8ac6-d53e59b0de20">
			<app:identifikasjon>
				<app:Identifikasjon>
					<app:lokalId>313058</app:lokalId>
					<app:navnerom>https://data.geonorge.no/sosi/stedsnavn</app:navnerom>
					<app:versjonId>20221201</app:versjonId>
				</app:Identifikasjon>
			</app:identifikasjon>
			<app:oppdateringsdato>2020-02-14T23:00:22+01:00</app:oppdateringsdato>
			<app:datauttaksdato>2026-08-14T06:30:56.496516+02:00</app:datauttaksdato>
			<app:posisjon>
				<gml:Point gml:id="id68f9d5f5-25fd-4df5-8ac6-d53e59b0de20-0" srsName="urn:ogc:def:crs:EPSG::4258" srsDimension="2">
					<gml:pos>61.636440 8.312477</gml:pos>
				</gml:Point>
			</app:posisjon>
			<app:stedsnavn>
				<app:Stedsnavn>
					<app:offentligBruk>true</app:offentligBruk>
					<app:navnesakstatus>ubehandlet</app:navnesakstatus>
					<app:navnestatus>hovednavn</app:navnestatus>
					<app:navnesaksstatusdato>1991-07-01</app:navnesaksstatusdato>
					<app:språk>norsk</app:språk>
					<app:stedsnavnnummer>1</app:stedsnavnnummer>
					<app:skrivemåte>
						<app:Skrivemåte>
							<app:komplettskrivemåte>Galdhøpiggen</app:komplettskrivemåte>
							<app:skrivemåtestatus>godkjent</app:skrivemåtestatus>
							<app:statusdato>1991-07-01</app:statusdato>
							<app:skrivemåtenummer>1</app:skrivemåtenummer>
						</app:Skrivemåte>
					</app:skrivemåte>
				</app:Stedsnavn>
			</app:stedsnavn>
			<app:land>Norge</app:land>
			<app:navneobjekthovedgruppe>terreng</app:navneobjekthovedgruppe>
			<app:navneobjektgruppe>høyder</app:navneobjektgruppe>
			<app:navneobjekttype>fjell</app:navneobjekttype>
			<app:sortering>viktighetH</app:sortering>
			<app:språkprioritering>norsk-sørsamisk-lulesamisk-nordsamisk-kvensk</app:språkprioritering>
			<app:kommune>
				<app:Kommune>
					<app:kommunenummer>3434</app:kommunenummer>
					<app:kommunenavn>Lom</app:kommunenavn>
					<app:fylkesnummer>34</app:fylkesnummer>
					<app:fylkesnavn>Innlandet</app:fylkesnavn>
				</app:Kommune>
			</app:kommune>
			<app:stedsnummer>313058</app:stedsnummer>
		</app:Sted></gml:featureMember>
	<!-- fixture case: multipoint -->
<gml:featureMember>
		<app:Sted gml:id="idf17233a5-5598-4eb1-8906-730269ab47cf">
			<app:identifikasjon>
				<app:Identifikasjon>
					<app:lokalId>488933</app:lokalId>
					<app:navnerom>https://data.geonorge.no/sosi/stedsnavn</app:navnerom>
					<app:versjonId>20221201</app:versjonId>
				</app:Identifikasjon>
			</app:identifikasjon>
			<app:oppdateringsdato>2020-02-14T23:00:16+01:00</app:oppdateringsdato>
			<app:datauttaksdato>2026-08-14T06:35:33.499544+02:00</app:datauttaksdato>
			<app:multipunkt>
				<gml:MultiPoint gml:id="idf17233a5-5598-4eb1-8906-730269ab47cf-0" srsName="urn:ogc:def:crs:EPSG::4258" srsDimension="2">
					<gml:pointMember>
						<gml:Point gml:id="idf17233a5-5598-4eb1-8906-730269ab47cf-1">
							<gml:pos>59.500206 6.088244</gml:pos>
						</gml:Point>
					</gml:pointMember>
					<gml:pointMember>
						<gml:Point gml:id="idf17233a5-5598-4eb1-8906-730269ab47cf-2">
							<gml:pos>59.501772 6.092103</gml:pos>
						</gml:Point>
					</gml:pointMember>
					<gml:pointMember>
						<gml:Point gml:id="idf17233a5-5598-4eb1-8906-730269ab47cf-3">
							<gml:pos>59.500156 6.088122</gml:pos>
						</gml:Point>
					</gml:pointMember>
					<gml:pointMember>
						<gml:Point gml:id="idf17233a5-5598-4eb1-8906-730269ab47cf-4">
							<gml:pos>59.504206 6.092319</gml:pos>
						</gml:Point>
					</gml:pointMember>
				</gml:MultiPoint>
			</app:multipunkt>
			<app:stedsnavn>
				<app:Stedsnavn>
					<app:offentligBruk>true</app:offentligBruk>
					<app:navnesakstatus>ubehandlet</app:navnesakstatus>
					<app:navnestatus>hovednavn</app:navnestatus>
					<app:navnesaksstatusdato>1991-07-01</app:navnesaksstatusdato>
					<app:språk>norsk</app:språk>
					<app:stedsnavnnummer>1</app:stedsnavnnummer>
					<app:skrivemåte>
						<app:Skrivemåte>
							<app:komplettskrivemåte>Grødnibbene</app:komplettskrivemåte>
							<app:skrivemåtestatus>godkjent</app:skrivemåtestatus>
							<app:statusdato>1991-07-01</app:statusdato>
							<app:skrivemåtenummer>1</app:skrivemåtenummer>
						</app:Skrivemåte>
					</app:skrivemåte>
					<app:annenSkrivemåte>
						<app:Skrivemåte>
							<app:komplettskrivemåte>Grønibbene</app:komplettskrivemåte>
							<app:skrivemåtestatus>godkjent</app:skrivemåtestatus>
							<app:statusdato>1991-07-01</app:statusdato>
							<app:skrivemåtenummer>2</app:skrivemåtenummer>
						</app:Skrivemåte>
					</app:annenSkrivemåte>
				</app:Stedsnavn>
			</app:stedsnavn>
			<app:land>Norge</app:land>
			<app:navneobjekthovedgruppe>terreng</app:navneobjekthovedgruppe>
			<app:navneobjektgruppe>høyder</app:navneobjektgruppe>
			<app:navneobjekttype>fjell</app:navneobjekttype>
			<app:sortering>viktighetH</app:sortering>
			<app:språkprioritering>norsk-sørsamisk-lulesamisk-nordsamisk-kvensk</app:språkprioritering>
			<app:kommune>
				<app:Kommune>
					<app:kommunenummer>1160</app:kommunenummer>
					<app:kommunenavn>Vindafjord</app:kommunenavn>
					<app:fylkesnummer>11</app:fylkesnummer>
					<app:fylkesnavn>Rogaland</app:fylkesnavn>
				</app:Kommune>
			</app:kommune>
			<app:stedsnummer>488933</app:stedsnummer>
		</app:Sted></gml:featureMember>
	<!-- fixture case: status_decides -->
<gml:featureMember>
		<app:Sted gml:id="idb67d210b-43c5-4627-b2cd-b389695d67f6">
			<app:identifikasjon>
				<app:Identifikasjon>
					<app:lokalId>445400</app:lokalId>
					<app:navnerom>https://data.geonorge.no/sosi/stedsnavn</app:navnerom>
					<app:versjonId>20221201</app:versjonId>
				</app:Identifikasjon>
			</app:identifikasjon>
			<app:oppdateringsdato>2021-06-08T18:47:51+02:00</app:oppdateringsdato>
			<app:datauttaksdato>2026-08-14T06:34:00.750612+02:00</app:datauttaksdato>
			<app:multipunkt>
				<gml:MultiPoint gml:id="idb67d210b-43c5-4627-b2cd-b389695d67f6-0" srsName="urn:ogc:def:crs:EPSG::4258" srsDimension="2">
					<gml:pointMember>
						<gml:Point gml:id="idb67d210b-43c5-4627-b2cd-b389695d67f6-1">
							<gml:pos>62.394103 11.607797</gml:pos>
						</gml:Point>
					</gml:pointMember>
					<gml:pointMember>
						<gml:Point gml:id="idb67d210b-43c5-4627-b2cd-b389695d67f6-2">
							<gml:pos>62.394106 11.607800</gml:pos>
						</gml:Point>
					</gml:pointMember>
					<gml:pointMember>
						<gml:Point gml:id="idb67d210b-43c5-4627-b2cd-b389695d67f6-3">
							<gml:pos>62.391944 11.606117</gml:pos>
						</gml:Point>
					</gml:pointMember>
				</gml:MultiPoint>
			</app:multipunkt>
			<app:stedsnavn>
				<app:Stedsnavn>
					<app:offentligBruk>true</app:offentligBruk>
					<app:navnesakstatus>iverksattVedtak</app:navnesakstatus>
					<app:navnestatus>hovednavn</app:navnestatus>
					<app:navnesaksstatusdato>1994-12-05</app:navnesaksstatusdato>
					<app:språk>norsk</app:språk>
					<app:stedsnavnnummer>1</app:stedsnavnnummer>
					<app:skrivemåte>
						<app:Skrivemåte>
							<app:komplettskrivemåte>Korssjøvola</app:komplettskrivemåte>
							<app:skrivemåtestatus>vedtatt</app:skrivemåtestatus>
							<app:statusdato>1994-12-05</app:statusdato>
							<app:skrivemåtenummer>1</app:skrivemåtenummer>
						</app:Skrivemåte>
					</app:skrivemåte>
				</app:Stedsnavn>
			</app:stedsnavn>
			<app:stedsnavn>
				<app:Stedsnavn>
					<app:offentligBruk>true</app:offentligBruk>
					<app:navnesakstatus>ubehandlet</app:navnesakstatus>
					<app:navnestatus>undernavn</app:navnestatus>
					<app:navnesaksstatusdato>1991-07-01</app:navnesaksstatusdato>
					<app:språk>norsk</app:språk>
					<app:stedsnavnnummer>2</app:stedsnavnnummer>
					<app:skrivemåte>
						<app:Skrivemåte>
							<app:komplettskrivemåte>Korssjøfjellet</app:komplettskrivemåte>
							<app:skrivemåtestatus>godkjent</app:skrivemåtestatus>
							<app:statusdato>1991-07-01</app:statusdato>
							<app:skrivemåtenummer>1</app:skrivemåtenummer>
						</app:Skrivemåte>
					</app:skrivemåte>
				</app:Stedsnavn>
			</app:stedsnavn>
			<app:land>Norge</app:land>
			<app:navneobjekthovedgruppe>terreng</app:navneobjekthovedgruppe>
			<app:navneobjektgruppe>høyder</app:navneobjektgruppe>
			<app:navneobjekttype>fjell</app:navneobjekttype>
			<app:sortering>viktighetH</app:sortering>
			<app:språkprioritering>sørsamisk-lulesamisk-nordsamisk-skoltesamisk-norsk-kvensk</app:språkprioritering>
			<app:kommune>
				<app:Kommune>
					<app:kommunenummer>5025</app:kommunenummer>
					<app:kommunenavn>Røros</app:kommunenavn>
					<app:fylkesnummer>50</app:fylkesnummer>
					<app:fylkesnavn>Trøndelag - Trööndelage</app:fylkesnavn>
				</app:Kommune>
			</app:kommune>
			<app:stedsnummer>445400</app:stedsnummer>
		</app:Sted></gml:featureMember>
	<!-- fixture case: number_decides -->
<gml:featureMember>
		<app:Sted gml:id="idcfe29afb-f032-430d-a16d-abca3095ecda">
			<app:identifikasjon>
				<app:Identifikasjon>
					<app:lokalId>185763</app:lokalId>
					<app:navnerom>https://data.geonorge.no/sosi/stedsnavn</app:navnerom>
					<app:versjonId>20221201</app:versjonId>
				</app:Identifikasjon>
			</app:identifikasjon>
			<app:oppdateringsdato>2026-02-12T09:21:37+01:00</app:oppdateringsdato>
			<app:datauttaksdato>2026-08-14T06:51:43.337659+02:00</app:datauttaksdato>
			<app:multipunkt>
				<gml:MultiPoint gml:id="idcfe29afb-f032-430d-a16d-abca3095ecda-0" srsName="urn:ogc:def:crs:EPSG::4258" srsDimension="2">
					<gml:pointMember>
						<gml:Point gml:id="idcfe29afb-f032-430d-a16d-abca3095ecda-1">
							<gml:pos>59.644511 6.233083</gml:pos>
						</gml:Point>
					</gml:pointMember>
					<gml:pointMember>
						<gml:Point gml:id="idcfe29afb-f032-430d-a16d-abca3095ecda-2">
							<gml:pos>59.644764 6.233475</gml:pos>
						</gml:Point>
					</gml:pointMember>
				</gml:MultiPoint>
			</app:multipunkt>
			<app:stedsnavn>
				<app:Stedsnavn>
					<app:offentligBruk>true</app:offentligBruk>
					<app:navnesakstatus>navnesakReist</app:navnesakstatus>
					<app:navnestatus>sidenavn</app:navnestatus>
					<app:navnesaksstatusdato>1991-07-01</app:navnesaksstatusdato>
					<app:språk>norsk</app:språk>
					<app:stedsnavnnummer>1</app:stedsnavnnummer>
					<app:skrivemåte>
						<app:Skrivemåte>
							<app:komplettskrivemåte>Svandalsgryvlenuten</app:komplettskrivemåte>
							<app:skrivemåtestatus>godkjent</app:skrivemåtestatus>
							<app:statusdato>1991-07-01</app:statusdato>
							<app:skrivemåtenummer>1</app:skrivemåtenummer>
						</app:Skrivemåte>
					</app:skrivemåte>
				</app:Stedsnavn>
			</app:stedsnavn>
			<app:stedsnavn>
				<app:Stedsnavn>
					<app:offentligBruk>true</app:offentligBruk>
					<app:navnesakstatus>navnesakReist</app:navnesakstatus>
					<app:navnestatus>sidenavn</app:navnestatus>
					<app:navnesaksstatusdato>1991-07-01</app:navnesaksstatusdato>
					<app:språk>norsk</app:språk>
					<app:stedsnavnnummer>2</app:stedsnavnnummer>
					<app:skrivemåte>
						<app:Skrivemåte>
							<app:komplettskrivemåte>Tjuanuten</app:komplettskrivemåte>
							<app:skrivemåtestatus>godkjent</app:skrivemåtestatus>
							<app:statusdato>1991-07-01</app:statusdato>
							<app:skrivemåtenummer>1</app:skrivemåtenummer>
						</app:Skrivemåte>
					</app:skrivemåte>
					<app:annenSkrivemåte>
						<app:Skrivemåte>
							<app:komplettskrivemåte>Tjuvanuten</app:komplettskrivemåte>
							<app:skrivemåtestatus>foreslått</app:skrivemåtestatus>
							<app:statusdato>1991-07-01</app:statusdato>
							<app:skrivemåtenummer>2</app:skrivemåtenummer>
						</app:Skrivemåte>
					</app:annenSkrivemåte>
				</app:Stedsnavn>
			</app:stedsnavn>
			<app:land>Norge</app:land>
			<app:navneobjekthovedgruppe>terreng</app:navneobjekthovedgruppe>
			<app:navneobjektgruppe>høyder</app:navneobjektgruppe>
			<app:navneobjekttype>fjell</app:navneobjekttype>
			<app:sortering>viktighetH</app:sortering>
			<app:språkprioritering>norsk-sørsamisk-lulesamisk-nordsamisk-kvensk</app:språkprioritering>
			<app:kommune>
				<app:Kommune>
					<app:kommunenummer>1135</app:kommunenummer>
					<app:kommunenavn>Sauda</app:kommunenavn>
					<app:fylkesnummer>11</app:fylkesnummer>
					<app:fylkesnavn>Rogaland</app:fylkesnavn>
				</app:Kommune>
			</app:kommune>
			<app:stedsnummer>185763</app:stedsnummer>
		</app:Sted></gml:featureMember>
	<!-- fixture case: language_decides_sami -->
<gml:featureMember>
		<app:Sted gml:id="id23749df1-358b-40d8-a111-e45da51153f4">
			<app:identifikasjon>
				<app:Identifikasjon>
					<app:lokalId>74621</app:lokalId>
					<app:navnerom>https://data.geonorge.no/sosi/stedsnavn</app:navnerom>
					<app:versjonId>20221201</app:versjonId>
				</app:Identifikasjon>
			</app:identifikasjon>
			<app:oppdateringsdato>2021-06-08T18:45:28+02:00</app:oppdateringsdato>
			<app:datauttaksdato>2026-08-14T06:27:17.493384+02:00</app:datauttaksdato>
			<app:multipunkt>
				<gml:MultiPoint gml:id="id23749df1-358b-40d8-a111-e45da51153f4-0" srsName="urn:ogc:def:crs:EPSG::4258" srsDimension="2">
					<gml:pointMember>
						<gml:Point gml:id="id23749df1-358b-40d8-a111-e45da51153f4-1">
							<gml:pos>64.054961 12.528983</gml:pos>
						</gml:Point>
					</gml:pointMember>
					<gml:pointMember>
						<gml:Point gml:id="id23749df1-358b-40d8-a111-e45da51153f4-2">
							<gml:pos>64.054961 12.528986</gml:pos>
						</gml:Point>
					</gml:pointMember>
				</gml:MultiPoint>
			</app:multipunkt>
			<app:stedsnavn>
				<app:Stedsnavn>
					<app:offentligBruk>true</app:offentligBruk>
					<app:navnesakstatus>ubehandlet</app:navnesakstatus>
					<app:navnestatus>hovednavn</app:navnestatus>
					<app:navnesaksstatusdato>1991-07-01</app:navnesaksstatusdato>
					<app:språk>norsk</app:språk>
					<app:stedsnavnnummer>1</app:stedsnavnnummer>
					<app:skrivemåte>
						<app:Skrivemåte>
							<app:komplettskrivemåte>Skjækerskaftet</app:komplettskrivemåte>
							<app:skrivemåtestatus>godkjent</app:skrivemåtestatus>
							<app:statusdato>1991-07-01</app:statusdato>
							<app:skrivemåtenummer>1</app:skrivemåtenummer>
						</app:Skrivemåte>
					</app:skrivemåte>
				</app:Stedsnavn>
			</app:stedsnavn>
			<app:stedsnavn>
				<app:Stedsnavn>
					<app:offentligBruk>true</app:offentligBruk>
					<app:navnesakstatus>iverksattVedtak</app:navnesakstatus>
					<app:navnestatus>hovednavn</app:navnestatus>
					<app:navnesaksstatusdato>1998-01-07</app:navnesaksstatusdato>
					<app:språk>sørsamisk</app:språk>
					<app:stedsnavnnummer>2</app:stedsnavnnummer>
					<app:skrivemåte>
						<app:Skrivemåte>
							<app:komplettskrivemåte>Rihkedetjahke</app:komplettskrivemåte>
							<app:skrivemåtestatus>vedtatt</app:skrivemåtestatus>
							<app:statusdato>1998-01-07</app:statusdato>
							<app:skrivemåtenummer>1</app:skrivemåtenummer>
						</app:Skrivemåte>
					</app:skrivemåte>
				</app:Stedsnavn>
			</app:stedsnavn>
			<app:land>Norge</app:land>
			<app:navneobjekthovedgruppe>terreng</app:navneobjekthovedgruppe>
			<app:navneobjektgruppe>høyder</app:navneobjektgruppe>
			<app:navneobjekttype>fjell</app:navneobjekttype>
			<app:sortering>viktighetH</app:sortering>
			<app:språkprioritering>sørsamisk-lulesamisk-nordsamisk-norsk-kvensk</app:språkprioritering>
			<app:kommune>
				<app:Kommune>
					<app:kommunenummer>5041</app:kommunenummer>
					<app:kommunenavn>Snåase - Snåsa</app:kommunenavn>
					<app:fylkesnummer>50</app:fylkesnummer>
					<app:fylkesnavn>Trøndelag - Trööndelage</app:fylkesnavn>
				</app:Kommune>
			</app:kommune>
			<app:stedsnummer>74621</app:stedsnummer>
		</app:Sted></gml:featureMember>
	<!-- fixture case: language_decides_norwegian -->
<gml:featureMember>
		<app:Sted gml:id="idd8d8f950-bb31-4c7d-95e8-ff439c5a57c7">
			<app:identifikasjon>
				<app:Identifikasjon>
					<app:lokalId>681313</app:lokalId>
					<app:navnerom>https://data.geonorge.no/sosi/stedsnavn</app:navnerom>
					<app:versjonId>20221201</app:versjonId>
				</app:Identifikasjon>
			</app:identifikasjon>
			<app:oppdateringsdato>2020-02-14T23:07:18+01:00</app:oppdateringsdato>
			<app:datauttaksdato>2026-08-14T06:16:43.115178+02:00</app:datauttaksdato>
			<app:multipunkt>
				<gml:MultiPoint gml:id="idd8d8f950-bb31-4c7d-95e8-ff439c5a57c7-0" srsName="urn:ogc:def:crs:EPSG::4258" srsDimension="2">
					<gml:pointMember>
						<gml:Point gml:id="idd8d8f950-bb31-4c7d-95e8-ff439c5a57c7-1">
							<gml:pos>64.323067 10.998047</gml:pos>
						</gml:Point>
					</gml:pointMember>
					<gml:pointMember>
						<gml:Point gml:id="idd8d8f950-bb31-4c7d-95e8-ff439c5a57c7-2">
							<gml:pos>64.323075 10.998056</gml:pos>
						</gml:Point>
					</gml:pointMember>
					<gml:pointMember>
						<gml:Point gml:id="idd8d8f950-bb31-4c7d-95e8-ff439c5a57c7-3">
							<gml:pos>64.323069 10.998050</gml:pos>
						</gml:Point>
					</gml:pointMember>
				</gml:MultiPoint>
			</app:multipunkt>
			<app:stedsnavn>
				<app:Stedsnavn>
					<app:offentligBruk>true</app:offentligBruk>
					<app:navnesakstatus>ubehandlet</app:navnesakstatus>
					<app:navnestatus>hovednavn</app:navnestatus>
					<app:navnesaksstatusdato>1991-07-01</app:navnesaksstatusdato>
					<app:språk>sørsamisk</app:språk>
					<app:stedsnavnnummer>1</app:stedsnavnnummer>
					<app:skrivemåte>
						<app:Skrivemåte>
							<app:komplettskrivemåte>Skaanja-Stoerrevaerie</app:komplettskrivemåte>
							<app:skrivemåtestatus>godkjent</app:skrivemåtestatus>
							<app:statusdato>1991-07-01</app:statusdato>
							<app:skrivemåtenummer>1</app:skrivemåtenummer>
						</app:Skrivemåte>
					</app:skrivemåte>
				</app:Stedsnavn>
			</app:stedsnavn>
			<app:stedsnavn>
				<app:Stedsnavn>
					<app:offentligBruk>true</app:offentligBruk>
					<app:navnesakstatus>ubehandlet</app:navnesakstatus>
					<app:navnestatus>hovednavn</app:navnestatus>
					<app:navnesaksstatusdato>1991-07-01</app:navnesaksstatusdato>
					<app:språk>norsk</app:språk>
					<app:stedsnavnnummer>2</app:stedsnavnnummer>
					<app:skrivemåte>
						<app:Skrivemåte>
							<app:komplettskrivemåte>Jøssundvarden</app:komplettskrivemåte>
							<app:skrivemåtestatus>godkjent</app:skrivemåtestatus>
							<app:statusdato>1991-07-01</app:statusdato>
							<app:skrivemåtenummer>1</app:skrivemåtenummer>
						</app:Skrivemåte>
					</app:skrivemåte>
				</app:Stedsnavn>
			</app:stedsnavn>
			<app:land>Norge</app:land>
			<app:navneobjekthovedgruppe>terreng</app:navneobjekthovedgruppe>
			<app:navneobjektgruppe>høyder</app:navneobjektgruppe>
			<app:navneobjekttype>fjell</app:navneobjekttype>
			<app:sortering>viktighetH</app:sortering>
			<app:språkprioritering>norsk-sørsamisk-lulesamisk-nordsamisk-kvensk</app:språkprioritering>
			<app:kommune>
				<app:Kommune>
					<app:kommunenummer>5007</app:kommunenummer>
					<app:kommunenavn>Namsos - Nåavmesjenjaelmie</app:kommunenavn>
					<app:fylkesnummer>50</app:fylkesnummer>
					<app:fylkesnavn>Trøndelag - Trööndelage</app:fylkesnavn>
				</app:Kommune>
			</app:kommune>
			<app:stedsnummer>681313</app:stedsnummer>
		</app:Sted></gml:featureMember>
	<!-- fixture case: topp -->
<gml:featureMember>
		<app:Sted gml:id="id57615027-a4b6-48cc-bace-742a1ff2869f">
			<app:identifikasjon>
				<app:Identifikasjon>
					<app:lokalId>64544</app:lokalId>
					<app:navnerom>https://data.geonorge.no/sosi/stedsnavn</app:navnerom>
					<app:versjonId>20221201</app:versjonId>
				</app:Identifikasjon>
			</app:identifikasjon>
			<app:oppdateringsdato>2023-12-29T10:26:34+01:00</app:oppdateringsdato>
			<app:datauttaksdato>2026-08-14T06:01:48.312255+02:00</app:datauttaksdato>
			<app:posisjon>
				<gml:Point gml:id="id57615027-a4b6-48cc-bace-742a1ff2869f-0" srsName="urn:ogc:def:crs:EPSG::4258" srsDimension="2">
					<gml:pos>59.807160 7.530395</gml:pos>
				</gml:Point>
			</app:posisjon>
			<app:stedsnavn>
				<app:Stedsnavn>
					<app:offentligBruk>true</app:offentligBruk>
					<app:navnesakstatus>ubehandlet</app:navnesakstatus>
					<app:navnestatus>hovednavn</app:navnestatus>
					<app:navnesaksstatusdato>1991-07-01</app:navnesaksstatusdato>
					<app:språk>norsk</app:språk>
					<app:stedsnavnnummer>1</app:stedsnavnnummer>
					<app:skrivemåte>
						<app:Skrivemåte>
							<app:komplettskrivemåte>Kaldebekknuten</app:komplettskrivemåte>
							<app:skrivemåtestatus>godkjent</app:skrivemåtestatus>
							<app:statusdato>1991-07-01</app:statusdato>
							<app:skrivemåtenummer>1</app:skrivemåtenummer>
						</app:Skrivemåte>
					</app:skrivemåte>
				</app:Stedsnavn>
			</app:stedsnavn>
			<app:land>Norge</app:land>
			<app:navneobjekthovedgruppe>terreng</app:navneobjekthovedgruppe>
			<app:navneobjektgruppe>høyder</app:navneobjektgruppe>
			<app:navneobjekttype>topp</app:navneobjekttype>
			<app:sortering>viktighetE</app:sortering>
			<app:språkprioritering>norsk-sørsamisk-lulesamisk-nordsamisk-kvensk</app:språkprioritering>
			<app:kommune>
				<app:Kommune>
					<app:kommunenummer>4036</app:kommunenummer>
					<app:kommunenavn>Vinje</app:kommunenavn>
					<app:fylkesnummer>40</app:fylkesnummer>
					<app:fylkesnavn>Telemark</app:fylkesnavn>
				</app:Kommune>
			</app:kommune>
			<app:stedsnummer>64544</app:stedsnummer>
		</app:Sted></gml:featureMember>
	<!-- fixture case: no_geometry -->
<gml:featureMember>
		<app:Sted gml:id="ide0fee36c-dbcc-4c35-8cec-2aabcf78eebb">
			<app:identifikasjon>
				<app:Identifikasjon>
					<app:lokalId>1077614</app:lokalId>
					<app:navnerom>https://data.geonorge.no/sosi/stedsnavn</app:navnerom>
					<app:versjonId>20221201</app:versjonId>
				</app:Identifikasjon>
			</app:identifikasjon>
			<app:oppdateringsdato>2023-12-29T10:26:57+01:00</app:oppdateringsdato>
			<app:datauttaksdato>2026-08-14T06:16:30.483121+02:00</app:datauttaksdato>
			<app:område>
				<gml:Surface gml:id="ide0fee36c-dbcc-4c35-8cec-2aabcf78eebb-0" srsName="urn:ogc:def:crs:EPSG::4258" srsDimension="2">
					<gml:patches>
						<gml:PolygonPatch>
							<gml:exterior>
								<gml:LinearRing>
									<gml:posList>69.603834 19.005631 69.625743 18.991059 69.625391 18.993229 69.615266 18.998909 69.603834 19.005631</gml:posList>
								</gml:LinearRing>
							</gml:exterior>
						</gml:PolygonPatch>
					</gml:patches>
				</gml:Surface>
			</app:område>
			<app:stedsnavn>
				<app:Stedsnavn>
					<app:offentligBruk>true</app:offentligBruk>
					<app:navnesakstatus>iverksattVedtak</app:navnesakstatus>
					<app:navnestatus>hovednavn</app:navnestatus>
					<app:navnesaksstatusdato>2020-07-09</app:navnesaksstatusdato>
					<app:språk>nordsamisk</app:språk>
					<app:stedsnavnnummer>1</app:stedsnavnnummer>
					<app:skrivemåte>
						<app:Skrivemåte>
							<app:komplettskrivemåte>Romssavárit</app:komplettskrivemåte>
							<app:skrivemåtestatus>vedtatt</app:skrivemåtestatus>
							<app:statusdato>2018-10-02</app:statusdato>
							<app:skrivemåtenummer>1</app:skrivemåtenummer>
						</app:Skrivemåte>
					</app:skrivemåte>
				</app:Stedsnavn>
			</app:stedsnavn>
			<app:land>Norge</app:land>
			<app:navneobjekthovedgruppe>terreng</app:navneobjekthovedgruppe>
			<app:navneobjektgruppe>høyder</app:navneobjektgruppe>
			<app:navneobjekttype>fjell</app:navneobjekttype>
			<app:sortering>viktighetH</app:sortering>
			<app:språkprioritering>norsk-nordsamisk-skoltesamisk-lulesamisk-sørsamisk-kvensk</app:språkprioritering>
			<app:kommune>
				<app:Kommune>
					<app:kommunenummer>5501</app:kommunenummer>
					<app:kommunenavn>Tromsø</app:kommunenavn>
					<app:fylkesnummer>55</app:fylkesnummer>
					<app:fylkesnavn>Troms - Romsa - Tromssa</app:fylkesnavn>
				</app:Kommune>
			</app:kommune>
			<app:stedsnummer>1077614</app:stedsnummer>
		</app:Sted></gml:featureMember>
	<!-- fixture case: not_a_peak -->
<gml:featureMember>
		<app:Sted gml:id="iddc1d51a2-8220-420e-96bb-96820ac66f58">
			<app:identifikasjon>
				<app:Identifikasjon>
					<app:lokalId>829767</app:lokalId>
					<app:navnerom>https://data.geonorge.no/sosi/stedsnavn</app:navnerom>
					<app:versjonId>20221201</app:versjonId>
				</app:Identifikasjon>
			</app:identifikasjon>
			<app:oppdateringsdato>2019-12-27T10:29:11+01:00</app:oppdateringsdato>
			<app:datauttaksdato>2026-08-14T06:19:15.803834+02:00</app:datauttaksdato>
			<app:multikurve>
				<gml:MultiCurve gml:id="iddc1d51a2-8220-420e-96bb-96820ac66f58-0" srsName="urn:ogc:def:crs:EPSG::4258" srsDimension="2">
					<gml:curveMember>
						<gml:LineString gml:id="iddc1d51a2-8220-420e-96bb-96820ac66f58-1">
							<gml:posList>60.589332 4.839375 60.589234 4.838520 60.589240 4.837943 60.589361 4.837234 60.589672 4.836451 60.590084 4.836020 60.590624 4.835806 60.593784 4.835809 60.594398 4.835707 60.594704 4.835470 60.595070 4.834960 60.595516 4.834066 60.598303 4.827960 60.598609 4.827437 60.599076 4.826957 60.599551 4.826823 60.606833 4.826792 60.613811 4.824176 60.614245 4.823895 60.614679 4.823276 60.615767 4.820691</gml:posList>
						</gml:LineString>
					</gml:curveMember>
					<gml:curveMember>
						<gml:LineString gml:id="iddc1d51a2-8220-420e-96bb-96820ac66f58-2">
							<gml:posList>60.590018 4.843742 60.589657 4.841456</gml:posList>
						</gml:LineString>
					</gml:curveMember>
					<gml:curveMember>
						<gml:LineString gml:id="iddc1d51a2-8220-420e-96bb-96820ac66f58-3">
							<gml:posList>60.590588 4.848057 60.590541 4.847263 60.590018 4.843742</gml:posList>
						</gml:LineString>
					</gml:curveMember>
					<gml:curveMember>
						<gml:LineString gml:id="iddc1d51a2-8220-420e-96bb-96820ac66f58-4">
							<gml:posList>60.615767 4.820691 60.616351 4.819415 60.617011 4.818545 60.617390 4.817758 60.618407 4.814755 60.619713 4.811625 60.619820 4.810981 60.619889 4.808325 60.620022 4.807661 60.620270 4.807015 60.620604 4.806523 60.621666 4.805665</gml:posList>
						</gml:LineString>
					</gml:curveMember>
					<gml:curveMember>
						<gml:LineString gml:id="iddc1d51a2-8220-420e-96bb-96820ac66f58-5">
							<gml:posList>60.621666 4.805665 60.621688 4.805864</gml:posList>
						</gml:LineString>
					</gml:curveMember>
					<gml:curveMember>
						<gml:LineString gml:id="iddc1d51a2-8220-420e-96bb-96820ac66f58-6">
							<gml:posList>60.621666 4.805665 60.622453 4.805059</gml:posList>
						</gml:LineString>
					</gml:curveMember>
					<gml:curveMember>
						<gml:LineString gml:id="iddc1d51a2-8220-420e-96bb-96820ac66f58-7">
							<gml:posList>60.622453 4.805059 60.622544 4.805040</gml:posList>
						</gml:LineString>
					</gml:curveMember>
					<gml:curveMember>
						<gml:LineString gml:id="iddc1d51a2-8220-420e-96bb-96820ac66f58-8">
							<gml:posList>60.622453 4.805059 60.622478 4.804868 60.622766 4.804658 60.622857 4.804438 60.622820 4.804236 60.622551 4.803891</gml:posList>
						</gml:LineString>
					</gml:curveMember>
					<gml:curveMember>
						<gml:LineString gml:id="iddc1d51a2-8220-420e-96bb-96820ac66f58-9">
							<gml:posList>60.622544 4.805040 60.622854 4.804982 60.623755 4.805130 60.624412 4.804763 60.624912 4.804154</gml:posList>
						</gml:LineString>
					</gml:curveMember>
				</gml:MultiCurve>
			</app:multikurve>
			<app:stedsnavn>
				<app:Stedsnavn>
					<app:offentligBruk>true</app:offentligBruk>
					<app:navnesakstatus>iverksattVedtak</app:navnesakstatus>
					<app:navnestatus>hovednavn</app:navnestatus>
					<app:navnesaksstatusdato>2016-05-10</app:navnesaksstatusdato>
					<app:språk>norsk</app:språk>
					<app:stedsnavnnummer>1</app:stedsnavnnummer>
					<app:skrivemåte>
						<app:Skrivemåte>
							<app:komplettskrivemåte>Alvøyvegen</app:komplettskrivemåte>
							<app:skrivemåtestatus>vedtatt</app:skrivemåtestatus>
							<app:statusdato>2001-07-05</app:statusdato>
							<app:skrivemåtenummer>1</app:skrivemåtenummer>
						</app:Skrivemåte>
					</app:skrivemåte>
				</app:Stedsnavn>
			</app:stedsnavn>
			<app:land>Norge</app:land>
			<app:navneobjekthovedgruppe>infrastruktur</app:navneobjekthovedgruppe>
			<app:navneobjektgruppe>veg</app:navneobjektgruppe>
			<app:navneobjekttype>adressenavn</app:navneobjekttype>
			<app:sortering>viktighetC</app:sortering>
			<app:språkprioritering>norsk-sørsamisk-lulesamisk-nordsamisk-kvensk</app:språkprioritering>
			<app:vegreferanse>
				<app:Vegreferanse>
					<app:matrikkelId>21533092</app:matrikkelId>
					<app:oppdateringsdato>2019-12-27T10:29:11.273+01:00</app:oppdateringsdato>
					<app:registreringsdato>2019-05-31T00:03:50.92+02:00</app:registreringsdato>
					<app:kommunenummer>4626</app:kommunenummer>
					<app:adressekode>3157</app:adressekode>
				</app:Vegreferanse>
			</app:vegreferanse>
			<app:kommune>
				<app:Kommune>
					<app:kommunenummer>4626</app:kommunenummer>
					<app:kommunenavn>Øygarden</app:kommunenavn>
					<app:fylkesnummer>46</app:fylkesnummer>
					<app:fylkesnavn>Vestland</app:fylkesnavn>
				</app:Kommune>
			</app:kommune>
			<app:stedsnummer>829767</app:stedsnummer>
		</app:Sted></gml:featureMember>
</gml:FeatureCollection>
