Just a little learning project to record voices from different iPad or iPhone devices, all with the same iCloud ID, and store the audio and some other data in cloudkit. So you have the same recordings on all devices, 

Usage case: For language exams in Austria, you need to record audios and keep them for some years, in case someone needs to verify that the exam was correct, as you need them e.g. to get the Austrian citizenship.

Future development:
* Add a picture of the candidate
* Add a picture of the ID card
* Add some other data like examiner, language level ...
* export a record as xml to make it available to another institution


Just a note from my side, this is almost my first Swift project (I did a small project about 5 years ago and pulished it on the Appstore within a few days for fun). I am heavily using the Windsurf/Claude 3.5 Sonnet AI to move forward and fix my bugs and learn. It's great for me.

To run this project, you need a paid Apple developer account, otherwise you will not be able to use cloudkit. In Sign&Capabilities, add your own team and bundle identifier.
Be aware that in the simulator sometimes is not working fine for recording and playing the audios, on a device it works fine. I´m using a macbook pro M1.
