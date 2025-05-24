//import SwiftUI
//
//struct DreamTrackerView: View {
//    var body: some View {
//        NavigationView {
//            VStack {
//                Text("Under Construction")
//                    .font(.largeTitle)
//                    .fontWeight(.bold)
//                    .foregroundColor(.gray)
//                
//                Spacer().frame(height: 20)
//                
//                Image(systemName: "hammer.fill")
//                    .font(.system(size: 60))
//                    .foregroundColor(.gray)
//                    .padding()
//            }
//        }
//    }
//}
//
//struct DreamTrackerView_Previews: PreviewProvider {
//    static var previews: some View {
//        DreamTrackerView()
//    }
//}

import SwiftUI

struct DreamTrackerView: View {
    var body: some View {
        DreamDashboardView()
    }
}

struct DreamTrackerView_Previews: PreviewProvider {
    static var previews: some View {
        DreamTrackerView()
    }
}
