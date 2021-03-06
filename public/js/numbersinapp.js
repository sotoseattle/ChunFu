var joker=""
var allowed= ['0', '○', '〇', 'Ｏ', '零', '1', '１', '一', '壹', '幺', '2', '２', '二', '兩', '貳', '两', '贰', '3', '３', '三', '參', '叁', '叄', '4', '４', '四', '肆', '5', '５', '五', '伍', '6', '６', '六', '陸', '陆', '7', '７', '七', '柒', '8', '８', '八', '捌', '9', '９', '九', '玖', '拾', '呀', '十', '佰', '百', '仟', '千', '億', '亿', '萬', '万', '廿', '念', '卅', '卌', '皕', '點', '点', '.', '、', ',', '負', '负', '-', '京', '兆', '亿', '万', '千', '百', '十']

var formulaic = {
  
  validate: function(choricete){
    for (var i = 0, len = choricete.length; i < len; i++) {
      if($.inArray(choricete[i], allowed) == -1) return false;
    };
    return true;
  },
  
  call_server_with_number: function(chinumber){
    $.ajax({
		  url: '/numberutil',
		  type: "get",
		  data: {sourcestring: chinumber},
		  success: function(data){
		    // turn on-off the grid to check alignment
		    //$("#horizontal-grid-overlay").css("display", "block");
		    
		    $("input#sourcestring").val("");
		    $("#expo").html("");
		    $("#expo2").html("");
	      $("#expo3").html("");
		    
		    answer= $.parseJSON(data)
		    $("#expo").append(answer.sol)
		    
		    $(".tt").tipTip({
          maxWidth: "auto", 
          edgeOffset: 5, 
          defaultPosition: "top",
          delay: 100
        });
		  },
		  error: function(){
		    $("#expo").html("<div id='intro'>Something went horribly wrong. Please post bellow the Chinese number that you tried so we can search for the \'bug\'.</div>");
		  }
		})
	},

	call_server_with_word: function(chiword){
    $.ajax({
	    url: '/wordutil',
	    type: "get",
	    data: {term: chiword},
	    success: function(data){
	      $("input#term").val("");
	      $("#expo").html("");
	      $("#expo2").html("");
	      $("#expo3").html("");
	      
	      answer= $.parseJSON(data)
	      $("#expo").append(answer.sol)

	      formulaic.call_server_deconstruct(chiword);

	    },
	    error: function(){
	      $("#expo").html("<div id='intro'>Something went horribly wrong. Please post bellow the Chinese number that you tried so we can search for the \'bug\'.</div>");
	    }
	  })
  },

  call_server_deconstruct: function(chiword){
    $.ajax({
	    url: '/deconstruct',
	    type: "get",
	    data: {term: chiword},
	    success: function(data){	      
	      answer= $.parseJSON(data)
	      $("#expo2").append(answer.sol)

	      formulaic.call_server_fuzzy(chiword);
	    },
	    error: function(){
	      $("#expo2").html("<div id='intro'>Something went horribly wrong. Please post bellow the Chinese number that you tried so we can search for the \'bug\'.</div>");
	    }
	  })
  },

	call_server_fuzzy: function(chiword){
    $.ajax({
	    url: '/fuzzy_search',
	    type: "get",
	    data: {term: chiword},
	    success: function(data){	      
	      answer= $.parseJSON(data)
	      $("#expo3").append(answer.sol)
	    },
	    error: function(){
	      $("#expo3").html("<div id='intro'>Something went horribly wrong. Please post bellow the Chinese number that you tried so we can search for the \'bug\'.</div>");
	    }
	  })
  },
  
	turn_on_form: function(){
		$("input#mysubmit").click(function(){
		  $("table#tabulary > tbody > tr").remove();
		  chinumber= $("input#sourcestring").val();
		  if (formulaic.validate(chinumber)){
		    formulaic.call_server_with_number(chinumber)
		  } else {
		    console.log("WRONG INPUT");
		    $("#expo").html("<div id='intro'><p>I am sorry, the input string \'"+chinumber+"\' is not recognized. Only the following characters are valid:</p><p>"+allowed.toString()+"</p></div>");
		  }
		  
		});
		$("input#mysubmit2").click(function(){
		  $("table#tabulary > tbody > tr").remove();
		  chiword= $("input#term").val();
		  formulaic.call_server_with_word(chiword)		  
		})

	}
}

$(document).keypress(function(e) {
  if(e.which == 13 && $("#sourcestring:focus").length==1) {
    $("input#mysubmit").click();
  } else if (e.which == 13 && $("#term:focus").length==1) {
  	$("input#mysubmit2").click();
  }
});

$(function () {
	formulaic.turn_on_form();
})

