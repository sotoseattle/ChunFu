var joker=""


var process_table = {
  
  rowify: function(str){
    return '<tr><td>'+str+'</td><td></td></tr>'
  }
  
};

var initialize_index = {
	
	turn_on_form: function(){
		$("input#mysubmit").click(function(){
		  $("table#tabulary > tbody > tr").remove();
		  
		  chinumber= $("input#sourcestring").val();
		  $.ajax({
  		  url: '/computa',
  		  type: "get",
  		  data: {sourcestring: chinumber},
  		  success: function(data){
  		    $("input#sourcestring").val("");
  		    $("#expo").html("");
  		    
  		    answer= $.parseJSON(data)
  		    $("#expo").append(answer.sol)
  		    
  		    $(".tt").tipTip({
            maxWidth: "auto", 
            edgeOffset: 5, 
            defaultPosition: "top",
            delay: 100
          });
  		    
  		  }
  		});
		})
	}
}

$(document).keypress(function(e) {
  if(e.which == 13 && $("#sourcestring:focus").length==1) {
    $("input#mysubmit").click();
  }
});

$(function () {
	initialize_index.turn_on_form();
})

