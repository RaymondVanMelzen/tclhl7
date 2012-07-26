#!/usr/bin/env tclsh

namespace eval HL7 {
	# This file contains code for spliting a message into a list-of-lists-of-lists.
	namespace eval Message {
		################################################################################
		# Public methods
		################################################################################
			proc parse {msgdata {segment_separator \r}} {
				# This proc splits a message into a list-of-lists-of-lists...
				# and returns the resulting message data structure.
				
				# get the separators
				set separators [get_separators $msgdata $segment_separator]
	
				# split the message into segments
				set segments [split_segments $msgdata $separators]
	
				return [list $segments $separators "PARSED_MESSAGE"]
			}
	
			proc has_been_parsed {msg} {
				set parsed_message [lindex $msg 2]
	
				return [expr {$parsed_message == "PARSED_MESSAGE"}]
			}
	
			proc data {msg} {
				# This proc builds the HL7 message from a parsed message.
				
				# verify that this is really a parsed message
				if { ![has_been_parsed $msg] } {
					error "This is not a parsed message."
				}
	
				set segments [lindex $msg 0]
				set separators [lindex $msg 1]
	
				return [build_message $segments $separators]
			}
	
		################################################################################
		# Private methods (not meant to be used externally)
		################################################################################
			proc get_separators {msgdata {segment_separator \r}} {
				# This proc returns an array with all of the separators of
				# an HL7 message.
				#
				# The following keys to the array are returned:
				# 	SEGMENT: segment separator
				# 	FIELD: field separator
				# 	REPETITION: repetition separator
				# 	COMPONENT: component separator
				# 	SUBCOMPONENT: subcomponent separator
				# 	ESCAPE: escape character
	
				array set separators {}
	
				set separators(SEGMENT) $segment_separator
				set separators(FIELD) [string index $msgdata 3]
				set separators(REPETITION) [string index $msgdata 5]
				set separators(COMPONENT) [string index $msgdata 4]
				set separators(SUBCOMPONENT) [string index $msgdata 7]
				set separators(ESCAPE) [string index $msgdata 6]
	
				return [array get separators]
			}
	
			########################################################################	
			# Split procs
			########################################################################	
				proc split_segments {msgdata separators} {
					# This proc splits a message into a list of parsed segments
	
					array set seps $separators
					set segments {}
	
					foreach segment [split $msgdata $seps(SEGMENT)] {
						# should we handle the MSH segment separately?
						if { [regexp {^MSH} $segment] } {
							lappend segments [split_msh_fields $segment $separators]
						} else {
							lappend segments [split_fields $segment $separators]
						}
					}
	
					return $segments
				}
	
				proc split_msh_fields {segment separators} {
					# This proc splits an MSH segment into a list of parsed fields
	
					array set seps $separators
	
					# initialize the resulting list of fields
					set final_fields [list "MSH" $seps(FIELD)]
	
					# split the fields
					set fields [split $segment $seps(FIELD)]
				
					# add the separator characters as the next field
					lappend final_fields [lindex $fields 1]
	
					# process the other fields
					foreach field [lrange $fields 2 end] {
						lappend final_fields [split_repetitions $field $separators]
					}
	
					return $final_fields
				}
	
				proc split_fields {segment separators} {
					# This proc splits a segment into a list of parsed fields
	
					array set seps $separators
					set fields {}
	
					foreach field [split $segment $seps(FIELD)] {
						lappend fields [split_repetitions $field $separators]
					}
	
					return $fields
				}
	
				proc split_repetitions {field separators} {
					# This proc splits a field into a list of parsed repetitions
	
					array set seps $separators
					set repetitions {}
	
					foreach repetition [split $field $seps(REPETITION)] {
						lappend repetitions [split_components $repetition $separators]
					}
	
					return $repetitions
				}
	
				proc split_components {repetition separators} {
					# This proc splits a repetition into a list of parsed components
	
					array set seps $separators
					set components {}
	
					foreach component [split $repetition $seps(COMPONENT)] {
						lappend components [split_subcomponents $component $separators]
					}
	
					return $components
				}
	
				proc split_subcomponents {component separators} {
					# This proc splits a component into a list of parsed subcomponents
	
					array set seps $separators
	
					return [split $component $seps(SUBCOMPONENT)]
				}
			########################################################################	
			# Rebuild procs
			########################################################################	
				proc build_message {segments separators} {
					array set seps $separators
	
					set rslts {}
	
					foreach segment $segments {
						if { [lindex $segment 0 0 0 0] == "MSH" } {
							lappend rslts [build_msh_segment $segment $separators]
						} else {
							lappend rslts [build_segment $segment $separators]
						}
					}
	
					return [join $rslts $seps(SEGMENT)]
				}
	
				proc build_msh_segment {fields separators} {
					array set seps $separators
	
	
					# build the separator string that will go in the message
					set sep_string [join [list $seps(COMPONENT) $seps(REPETITION) $seps(ESCAPE) $seps(SUBCOMPONENT) ] ""]
	
					# take the "sep_string" from a subcomponent to a field
					set msh_2 [list [list [list $sep_string]]]
	
					# Replace MSH.1 and the current value of MSH.2 with this
					# new value calculated off of the separators in the parsed
					# message.  We replace both MSH.1 and MSH.2 so that buid_segment
					# can correctly rebuild the MSH segment, since the HL7 standard
					# numbers the MSH segment differently from every other segment.
					set fields [lreplace $fields 1 2 $msh_2]
	
					return [build_segment $fields $separators]
				}
	
				proc build_segment {fields separators} {
					array set seps $separators
	
					set rslts {}
	
					foreach field $fields {
						lappend rslts [build_field $field $separators]
					}
	
					return [join $rslts $seps(FIELD)]
				}
	
				proc build_field {repetitions separators} {
					array set seps $separators
	
					set rslts {}
	
					foreach repetition $repetitions {
						lappend rslts [build_repetition $repetition $separators]
					}
	
					return [join $rslts $seps(REPETITION)]
				}
	
				proc build_repetition {components separators} {
					array set seps $separators
	
					set rslts {}
	
					foreach component $components {
						lappend rslts [build_component $component $separators]
					}
	
					return [join $rslts $seps(COMPONENT)]
				}
	
				proc build_component {subcomponents separators} {
					array set seps $separators
					return [join $subcomponents $seps(SUBCOMPONENT)]
				}
	}
	
	
	# This file contains code for turning an HL7 query address into a static address.
	namespace eval Query {
	
		################################################################################
		# Public methods
		################################################################################
			proc query {msg query {expand 0}} {
				# This proc turns an HL7 query address into a list
				# of all matching static addresses.
				#
				# A query address has the following formats:
				# 	- SEGMENT.FIELD.REPETITION.COMPONENT.SUBCOMPONENT
				# 		- returns subcomponent
				# 	- SEGMENT.FIELD.REPETITION.COMPONENT
				# 		- returns component (list of subcomponents)
				# 	- SEGMENT.FIELD.REPETITION
				# 		- returns repetition (list of components)
				# 	- SEGMENT.FIELD
				# 		- returns field (list of repetitions)
				# 	- SEGMENT
				# 		- returns segment (list of fields)
	
				# verify that the "msg" has been parsed
				if { ![HL7::Message::has_been_parsed $msg] } {
					error "The message must be parsed."
				}
	
				# split the query into each part
				set query_parts [split $query "."]
				set num_parts [llength $query_parts]
	
				# verify that the query parts are of the right length
				if { $num_parts > 5 } {
					error "Too many query parts. Between 1 and 5 parts allowed."
				} elseif { $num_parts <= 0 } {
					error "Not enough query parts. Between 1 and 5 parts allowed."
				}
	
	
				return [query_segments $msg $query_parts $expand]
			}
		################################################################################
		# Private methods (not intended for external use)
		################################################################################
		
			########################################################################
			# Query procs
			########################################################################
				proc query_segments {msg query_parts expand} {
					# initialize the list of resulting static addresses
					set addresses {}
	
					# get the segment and field parts of the query
					set seg_part [lindex $query_parts 0]
					set field_part [lindex $query_parts 1]
	
					# get the list of segments in the message
					set segments [lindex $msg 0]
					set num_segments [llength $segments]
	
					for {set i 0} {$i < $num_segments} {incr i} {
						# does this one match?
						if { [match_segment $segments $i $seg_part] } {
							# yes, it matches, thus we process it
	
							if { $field_part != "" } {
								foreach address [query_fields [lindex $segments $i] $query_parts $expand] {
									lappend addresses "$i.$address"
								}
							} else {
								lappend addresses $i
							}
						}
					}
	
					# return the list of accumulated addresses
					return $addresses
				}
	
				proc query_fields {segment query_parts expand} {
					# initialize the list of resulting static addresses
					set addresses {}
	
					# get the field and repetition parts of the query
					set field_part [lindex $query_parts 1]
					set rep_part [lindex $query_parts 2]
	
					# get the list of fields in the segment
					set num_fields [llength $segment]
	
					foreach i [query_indexes $num_fields $field_part 1] {
						if { $rep_part != "" } {
							set field [lindex $segment $i]
							foreach address [query_repetitions $field $query_parts $expand] {
								lappend addresses "${i}.${address}"
							}
						} else {
							lappend addresses $i
						}
					}
	
					# return the list of accumulated addresses
					return $addresses
	
				}
	
				proc query_repetitions {field query_parts expand} {
					# initialize the list of resulting static addresses
					set addresses {}
	
					# get the repetition and component parts of the query
					set rep_part [lindex $query_parts 2]
					set comp_part [lindex $query_parts 3]
	
					# get the list of repetitions in the field
					set num_repetitions [llength $field]
	
					foreach i [query_indexes $num_repetitions $rep_part $expand] {
						if { $comp_part != "" } {
							set repetition [lindex $field $i]
							foreach address [query_components $repetition $query_parts $expand] {
								lappend addresses "${i}.${address}"
							}
						} else {
							lappend addresses $i
						}
					}
	
					# return the list of accumulated addresses
					return $addresses
	
				}
	
				proc query_components {repetition query_parts expand} {
					# initialize the list of resulting static addresses
					set addresses {}
	
					# get the component and subcomponent parts of the query
					set comp_part [lindex $query_parts 3]
					set subcomp_part [lindex $query_parts 4]
	
					# get the list of components in the repetition
					set num_components [llength $repetition]
	
					foreach i [query_indexes $num_components $comp_part $expand] {
						if { $subcomp_part != "" } {
							set component [lindex $repetition $i]
							foreach address [query_subcomponents $component $query_parts $expand] {
								lappend addresses "${i}.${address}"
							}
						} else {
							lappend addresses $i
						}
					}
	
					# return the list of accumulated addresses
					return $addresses
	
				}
	
				proc query_subcomponents {component query_parts expand} {
					# initialize the list of resulting static addresses
					set addresses {}
	
					# get the subcomponent parts of the query
					set subcomp_part [lindex $query_parts 4]
	
					# get the list of subcomponents in the component
					set num_subcomponents [llength $component]
	
					foreach i [query_indexes $num_subcomponents $subcomp_part $expand] {
						lappend addresses $i
					}
	
					# return the list of accumulated addresses
					return $addresses
	
				}
	
	
				proc query_indexes {count query_part expand} {
					array set addresses {}
	
					foreach query [split $query_part ","] {
						switch -regexp -- $query {
							{^[0-9]+$} {
								if { $expand || $query < $count } {
									set addresses($query) 1
								}
							}
				
							{^\*$} {
								foreach address [range 0 $count 0] {
									set addresses($address) 1
								}
							}
	
							{^[0-9]+-[0-9]+$} {
								regexp {^([0-9]+)-([0-9]+)$} $query {} min max
								foreach address [range $min $max] {
									if { $expand || $address < $count } {
										set addresses($address) 1
									}
								}
							}
						}
					}
	
					return [lsort -integer [array names addresses]]
				}
	
				proc range {start end {inclusive 1}} {
					set rslts {}
	
					if { $inclusive } {
						incr end
					}
	
					for {set i $start} {$i < $end} {incr i} {
						lappend rslts $i
					}
					
					return $rslts
				}
		
			########################################################################
			# Match procs
			########################################################################
				proc match_segment {segments index seg_query} {
					# This proc returns 1 if the segment at the given
					# index matches the given query
	
					# get the segment type
					set seg_type [lindex $segments $index 0 0 0 0]
	
					# split the query
					foreach query [split $seg_query ","] {
						# check on segment type and index
						if { $seg_type == $query || $index == $query } {
							return 1
						}
					}
	
					return 0
				}
	
				proc match_field {fields index field_query} {
					# This proc returns 1 if the field at the given
					# index matches the given query
	
					# split the query
					foreach query [split $field_query ","] {
						# check index
						if { $index == $query } {
							return 1
						}
					}
	
					return 0
	
				}
	
			
	}
	

	# This file contains procs for getting data from and modifying HL7 messages.
	namespace eval GetSet {
		################################################################################
		# Public Methods
		################################################################################
			proc get {msg query} {
				# This proc pulls the values from the parsed message that match
				# the given query.
				#
				# The results are a list of "value-address" pairs.  Thus, for
				# the following message:
				# 	MSH|....|
				# 	PID|||123456~abcdef
				# and the query "PID.3.*", you get the following results:
				# 	{ {123456 1.3.0} {abcdef 1.3.1} }
				#
				# The address returned is a "static address" that can be
				# used to address a given field, repetition, component, etc.
				# specifically.
				# 
				# You would usually use this proc in the following manner:
				# 	set msg [hl7 parse $msgdata \r]
				# 	
				# 	foreach rslt [hl7 get $msg PID.3.*.0.0] {
				#		set value [lindex $rslt 0]
				#		set address [lindex $rslt 1]
				#
				#		# do something
				#		puts "$address ==> $value"
				# 	}
				set results {}
	
				foreach address [HL7::Query::query $msg $query] {
					set value [eval {lindex $msg 0} [split $address "."]]
					lappend results [list $value $address]
				}
	
				return $results
			}
	
			proc _set {msg query value {expand 1}} {
				# This proc sets the value of a segment, field, etc.
	
				# get the segments in the message
				set segments [lindex $msg 0]
	
				foreach address [HL7::Query::query $msg $query $expand] {
					set indexes [split $address "."]
					set segments [lexpand $segments $indexes]
					lset segments $indexes $value
				}
	
				# add the segments back into the message
				set msg [lreplace $msg 0 0 $segments]
	
				return $msg
			}
	
			proc each {msg query value_var address_var body} {
				proc __each_proc [list $value_var $address_var] $body
	
				foreach rslt [get $msg $query] {
					set value [lindex $rslt 0]
					set address [lindex $rslt 1]
					__each_proc $value $address 		
				}
			}
	
		################################################################################
		# Private Methods (not meant to be used externally)
		################################################################################
			proc lexpand {l indexes} {
				# short-circuit if we don't have any indexes to expand to.
				if { [llength $indexes] <= 0} {
					return $l
				}
	
				# pop off the next index
				set i [lindex $indexes 0]
				set indexes [lrange $indexes 1 end]
	
				# get the length of the current list
				set len [llength $l]
	
				# do we need to add more at this level?
				if { $i >= $len } {
					# yes...add more
					
					set count [expr {$i + 1 - $len}]
					while { $count > 0 } {
						lappend l {}
						incr count -1
					}
				}
	
				# do we need to process deeper?
				if { [llength $indexes] > 0 } {
					# yes
					set l [lreplace $l $i $i [lexpand [lindex $l $i] $indexes]]
				}
	
				return $l
			}
	}
	
}

proc hl7 {cmd args} {
	switch -exact -- $cmd {
		parse { return [eval {HL7::Message::parse} $args] }
		data { return [eval {HL7::Message::data} $args] }

		query { return [eval {HL7::Query::query} $args] }

		get { return [eval {HL7::GetSet::get} $args] }
		set { return [eval {HL7::GetSet::_set} $args] }
		each { return [eval {HL7::GetSet::each} $args] }

		default {
			error "Unknown command: $cmd"
		}
	}
}

