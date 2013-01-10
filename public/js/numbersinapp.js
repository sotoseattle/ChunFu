var joker=""
var allowed= ['0', '○', '〇', 'Ｏ', '零', '1', '１', '一', '壹', '幺', '2', '２', '二', '兩', '貳', '两', '贰', '3', '３', '三', '參', '叁', '叄', '4', '４', '四', '肆', '5', '５', '五', '伍', '6', '６', '六', '陸', '陆', '7', '７', '七', '柒', '8', '８', '八', '捌', '9', '９', '九', '玖', '拾', '呀', '十', '佰', '百', '仟', '千', '億', '亿', '萬', '万', '廿', '念', '卅', '卌', '皕', '點', '点', '.', '、', ',', '負', '负', '-', '京', '兆', '亿', '万', '千', '百', '十']

var formulaic = {
  
  validate: function(choricete){
    for (var i = 0, len = choricete.length; i < len; i++) {
      if($.inArray(choricete[i], allowed) == -1) return false;
    };
    return true;
  },
  
  callServer: function(chinumber){
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
		  },
		  error: function(){
		    $("#expo").html("<div id='warn'><p>Something went horribly wrong. Please post bellow the Chinese number that you tried so we can search for the \'bug\'.</p></div>");
		  }
		});
  },
	
	turn_on_form: function(){
		$("input#mysubmit").click(function(){
		  $("table#tabulary > tbody > tr").remove();
		  chinumber= $("input#sourcestring").val();
		  if (formulaic.validate(chinumber)){
		    formulaic.callServer(chinumber)
		  } else {
		    console.log("WRONG INPUT");
		    $("#expo").html("<div id='warn'><p>I am sorry, the input string \'"+chinumber+"\' is not recognized. Only the following characters are valid:</p><p>"+allowed.toString()+"</p></div>");
		  }
		  
		  
		})
	}
}

$(document).keypress(function(e) {
  if(e.which == 13 && $("#sourcestring:focus").length==1) {
    $("input#mysubmit").click();
  }
});

$(function () {
	formulaic.turn_on_form();
})

