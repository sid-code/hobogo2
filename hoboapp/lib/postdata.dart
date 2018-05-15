class PostData {
  String homeLoc;
  List<String> destList;
  int startTime;
  int endTime;
  int maxStay;
  int minStay;
  int maxPrice;
  int minLength;
  int passengers;

  String googleCantJSONThingsSoIWillDoIt(){
    String retVal = '{';
    retVal += jsonField('homeloc') + '\"' + homeLoc + '\",';
    retVal += jsonField('destlist') + '[';
    for(int i = 0;i < destList.length;i++){
      if(i < destList.length - 1){
        retVal += '\"' + destList[i] + '\"' + ',';
      } else {
        retVal += '\"' + destList[i] + '\"';
      }
    }
    retVal += '],';
    retVal += jsonField('starttime') + startTime.toString() + ',';
    retVal += jsonField('endtime') + endTime.toString() + ',';
    retVal += jsonField('maxstay') + maxStay.toString() + ',';
    retVal += jsonField('minstay') + minStay.toString() + ',';
    retVal += jsonField('maxprice') + maxPrice.toString() + ',';
    retVal += jsonField('minlength') + minLength.toString() + ',';
    retVal += jsonField('passengers') + passengers.toString();
    retVal += '}';
    return retVal;
  }

  String jsonField(String name){
    return '\"' + name + '\":';
  }
}
